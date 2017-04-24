$LOAD_PATH.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'pg_ltree/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'pg_ltree'
  s.version     = PgLtree::VERSION
  s.authors     = ['Andrei Panamarenka']
  s.email       = ['andrei.panamarenka@gmail.com']
  s.homepage    = 'https://github.com/sjke/pg_ltree'
  s.summary     = 'Organise ActiveRecord model into a tree structure with PostgreSQL LTree'
  s.description = 'Organise ActiveRecord model into a tree structure with PostgreSQL LTree'
  s.license     = 'MIT'
  s.required_ruby_version = '>= 2.0.0'

  s.files = Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.rdoc']
  s.test_files = Dir['test/**/*']

  s.add_dependency 'activerecord', '>= 4.0.0', '< 5.2'
  s.add_dependency 'pg', '>= 0.17.0', '< 0.21'

  s.add_development_dependency 'bundler'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'pry'
  s.add_development_dependency 'yard'
  s.add_development_dependency 'minitest'
end
