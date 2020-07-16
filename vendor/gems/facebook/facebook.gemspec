$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "facebook/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "facebook"
  s.version     = Facebook::VERSION
  s.authors     = ["Suman Kumar"]
  s.email       = ["sumankumar@freshdesk.com"]
  s.homepage    = "http://github.com/freshdesk/facebook"
  s.summary     = "Facebook Realtime Engine"
  s.description = "Facebook Realtime and PageTab Plugin"

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.rdoc","init.rb"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 3.2.18"
end
