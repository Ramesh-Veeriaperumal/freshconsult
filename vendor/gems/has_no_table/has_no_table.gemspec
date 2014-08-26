$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "has_no_table/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "has_no_table"
  s.version     = HasNoTable::VERSION
  s.authors     = ["Suman Kumar"]
  s.email       = ["sumankumar@freshdesk.com"]
  s.homepage    = "http://github.com/freshdesk/text_data_store"
  s.summary     = "Tableless ActiveRecord"
  s.description = "Has No Table"

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 3.2.18"
end
