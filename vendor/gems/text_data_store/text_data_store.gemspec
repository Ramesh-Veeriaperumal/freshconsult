$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "text_data_store/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "text_data_store"
  s.version     = TextDataStore::VERSION
  s.authors     = ["Suman Kumar"]
  s.email       = ["sumankumar@freshdesk.com"]
  s.homepage    = "http://github.com/freshdesk/text_data_store"
  s.summary     = "Text Data Store for choosing multiple backends"
  s.description = "Text Data Store callbacks gets added automatically"

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 3.2.18"
end
