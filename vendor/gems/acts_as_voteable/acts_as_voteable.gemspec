$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "acts_as_voteable/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "acts_as_voteable"
  s.version     = ActsAsVoteable::VERSION
  s.authors     = ["suman kumar dey"]
  s.email       = ["sumankumar@freshdesk.com"]
  s.homepage    = "http://juixe.com/svn/acts_as_voteable"
  s.summary     = "Allows user to vote on the on models."
  s.description = "Acts As Voteable allows user to vote on the models"

  s.files = Dir["{lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 3.2.18"
end
