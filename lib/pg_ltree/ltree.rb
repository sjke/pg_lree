module PgLtree
  # Implementatios Postgres ltree for ActiveRecord
  #
  # @see [ActiveRecord::Base]
  # @see http://www.postgresql.org/docs/current/static/ltree.html
  #
  # @author a.ponomarenko
  module Ltree
    # Initialzie ltree for active model
    #
    # @param column [String] ltree column name
    def ltree(column = :path, options: { cascade: true })
      cattr_accessor :ltree_path_column

      self.ltree_path_column = column

      if options[:cascade]
        after_update :cascade_update
        after_destroy :cascade_destroy
      end

      extend ClassMethods
      include InstanceMethods
    end

    # Define class methods
    module ClassMethods
      # Get roots
      #
      # @return [ActiveRecord::Relation] relations of node's roots
      def roots
        at_depth 1
      end

      # Get nodes on the level
      #
      # @param depth [Integer] Depth of the nodes
      # @return [ActiveRecord::Relation] relations of nodes for the depth
      def at_depth(depth)
        where "NLEVEL(#{table_name}.#{ltree_path_column}) = ?", depth
      end

      # Get all leaves
      #
      # @return [ActiveRecord::Relation] relations of node's leaves
      def leaves
        subquery =
          unscoped.select("COUNT(subquery.#{ltree_path_column}) = 1")
                  .from("#{table_name} AS subquery")
                  .where("subquery.#{ltree_path_column} <@ #{table_name}.#{ltree_path_column}")
        subquery = subquery.where(subquery: current_scope.where_values_hash) if current_scope
        where subquery.to_sql
      end

      # Get all with nodes when path liked the lquery
      #
      # @param lquery [String] ltree query
      # @return [ActiveRecord::Relation] relations of node'
      def where_path_liked(lquery)
        where "#{table_name}.#{ltree_path_column} ~ ?", lquery
      end

      # Get all nodes with path matching full-text-search-like pattern
      #
      # @param ltxtquery [String] ltree search query
      # @return [ActiveRecord::Relation] of matching nodes
      def where_path_matches_ltxtquery(ltxtquery)
        where "#{table_name}.#{ltree_path_column} @ ?", ltxtquery
      end
    end

    # Define instance methods
    module InstanceMethods
      # Get default scope of ltree
      #
      # @return current class
      def ltree_scope
        self.class
      end

      # Get lTree column
      #
      # @return [String] ltree column name
      def ltree_path_column
        ltree_scope.ltree_path_column
      end

      # Get lTree value
      #
      # @return [String] ltree current value
      def ltree_path
        public_send ltree_path_column
      end

      # Get ltree original value before the save just occurred
      # https://api.rubyonrails.org/classes/ActiveRecord/AttributeMethods/Dirty.html#method-i-attribute_before_last_save
      #
      # @return [String] ltree previous value
      def ltree_path_before_last_save
        public_send :attribute_before_last_save, ltree_path_column
      end

      # Get lTree previous value
      # originally +attribute_was+ used in before create/update, destroy won't call +save+ so this work
      # https://api.rubyonrails.org/classes/ActiveRecord/AttributeMethods/Dirty.html#method-i-attribute_in_database
      #
      # @return [String] ltree value in database

      def ltree_path_in_database
        public_send :attribute_in_database, ltree_path_column
      end

      # Check what current node is root
      #
      # @return [Boolean] True - for root node, False - for childen node
      def root?
        depth == 1
      end

      # Get node height
      #
      # The height of a node is the number of edges
      # on the longest downward path between that node and a leaf. The leaf nodes have height zero,
      # and a tree with only a single node (hence both a root and leaf) has height zero.
      # Conventionally, an empty tree (tree with no nodes, if such are allowed) has depth and height −1
      #
      # @return [Number] height of the given node. Height of the tree for root node.
      def height
        self_and_descendants.maximum("NLEVEL(#{ltree_path_column})") - depth.to_i
      end

      # Get node depth
      #
      # @return [Integer] node depth
      def depth
        ActiveRecord::Base.connection.select_all("SELECT NLEVEL('#{ltree_path}')").rows.flatten.first.to_i
      end

      # Get root of the node
      #
      # return [Object] root node
      def root
        ltree_scope.where("#{ltree_scope.table_name}.#{ltree_path_column} = SUBPATH(?, 0, 1)", ltree_path).first
      end

      # Get parent of the node
      #
      # return [Object] root node
      def parent
        ltree_scope.find_by "#{ltree_scope.table_name}.#{ltree_path_column} = SUBPATH(?, 0, NLEVEL(?) - 1)", ltree_path, ltree_path
      end

      # Get leaves of the node
      #
      # @return [ActiveRecord::Relation]
      def leaves
        ltree_scope.leaves.where("#{ltree_scope.table_name}.#{ltree_path_column} <@ ?", ltree_path).where.not ltree_path_column => ltree_path
      end

      # Check what current node have leaves
      #
      # @return [Boolean] True - if node have leaves, False - if node doesn't have leaves
      def leaf?
        leaves.count == 0
      end

      # Get self and ancestors
      #
      # @return [ActiveRecord::Relation]
      def self_and_ancestors
        ltree_scope.where("#{ltree_scope.table_name}.#{ltree_path_column} @> ?", ltree_path)
      end

      # Get ancestors
      #
      # @return [ActiveRecord::Relation]
      def ancestors
        self_and_ancestors.where.not ltree_path_column => ltree_path
      end

      # Get self and descendants
      #
      # @return [ActiveRecord::Relation]
      def self_and_descendants
        ltree_scope.where("#{ltree_scope.table_name}.#{ltree_path_column} <@ ?", ltree_path)
      end

      # Get self and descendants
      # @deprecated Please use {#self_and_descendants} instead
      # @return [ActiveRecord::Relation]
      def self_and_descendents
        warn '[DEPRECATION] `self_and_descendents` is deprecated. Please use `self_and_descendants` instead.'
        self_and_descendants
      end

      # Get descendants
      #
      # @return [ActiveRecord::Relation]
      def descendants
        self_and_descendants.where.not ltree_path_column => ltree_path
      end

      # Get descendants
      # @deprecated Please use {#descendants} instead
      # @return [ActiveRecord::Relation]
      def descendents
        warn '[DEPRECATION] `descendents` is deprecated. Please use `descendants` instead.'
        descendants
      end

      # Get self and siblings
      #
      # @return [ActiveRecord::Relation]
      def self_and_siblings
        ltree_scope.where(
          "SUBPATH(?, 0, NLEVEL(?) - 1) @> #{ltree_scope.table_name}.#{ltree_path_column} AND nlevel(#{ltree_scope.table_name}.#{ltree_path_column}) = NLEVEL(?)",
          ltree_path, ltree_path, ltree_path
        )
      end

      # Get siblings
      #
      # @return [ActiveRecord::Relation]
      def siblings
        self_and_siblings.where.not ltree_path_column => ltree_path
      end

      # Get children
      #
      # @return [ActiveRecord::Relation]
      def children
        ltree_scope.where "? @> #{ltree_scope.table_name}.#{ltree_path_column} AND nlevel(#{ltree_scope.table_name}.#{ltree_path_column}) = NLEVEL(?) + 1",
                          ltree_path, ltree_path
      end

      # Update all childen for current path
      #
      # @return [ActiveRecord::Relation]
      def cascade_update
        ltree_scope.where(["#{ltree_scope.table_name}.#{ltree_path_column} <@ ?", ltree_path_before_last_save]).where(["#{ltree_scope.table_name}.#{ltree_path_column} != ?", ltree_path])
                   .update_all ["#{ltree_path_column} = ? || subpath(#{ltree_path_column}, nlevel(?))", ltree_path, ltree_path_before_last_save]
      end

      # Delete all children for current path
      #
      # @return [ActiveRecord::Relation]
      def cascade_destroy
        ltree_scope.where("#{ltree_scope.table_name}.#{ltree_path_column} <@ ?", ltree_path_in_database).delete_all
      end
    end
  end
end
