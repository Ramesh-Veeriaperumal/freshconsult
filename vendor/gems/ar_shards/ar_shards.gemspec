$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "ar_shards/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "ar_shards"
  s.version     = ArShards::VERSION
  s.authors     = ["kiran darisi"]
  s.email       = ["kiran@freshdesk.com"]
  s.homepage    = "https://github.com/freshdesk/ar_shards"
  s.summary     = "AR SHARDS"
  s.description = "AR SHARDS CONNECTION SWITCHER"

  s.files = Dir["{lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 3.2.18"
end
