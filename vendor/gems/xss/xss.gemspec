$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "xss/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "xss"
  s.version     = Xss::VERSION
  s.authors     = ["Suman Kumar"]
  s.email       = ["sumankumar@freshdesk.com"]
  s.homepage    = "http://github.com/freshdesk/text_data_store"
  s.summary     = "Xss termination"
  s.description = "Xss termination"

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails"
end
