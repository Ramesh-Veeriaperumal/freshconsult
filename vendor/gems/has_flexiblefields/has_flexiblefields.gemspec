$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "has_flexiblefields/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "has_flexiblefields"
  s.version     = HasFlexiblefields::VERSION
  s.authors     = ["suman kumar dey"]
  s.email       = ["sumankumar@freshdesk.com"]
  s.homepage    = "http://github.com/freshdesk/has_flexiblefields"
  s.summary     = "has_flexible_fields plugin."
  s.description = "has_flexible_fields plugin"

  s.files = Dir["{lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails"
end
