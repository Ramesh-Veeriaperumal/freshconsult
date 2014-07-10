Gem::Specification.new do |s|
  s.name        = "freshdesk_authority"
  s.version     = "0.1"
  s.authors     = ["Shan Krishnasamy", "Gautham Shankar"]
  s.email       = ["shan@freshdesk.com", "gautham@freshdesk.com"]
  s.homepage    = "https://github.com/freshdesk/freshdesk_authority"
  s.summary     = "Rails authorization solution"
  s.description = "Rails authorization solution with a routes like specifications file"

  s.files        = Dir["{lib,spec}/**/*", "[A-Z]*", "init.rb"]
  s.require_path = "lib"

  s.add_development_dependency 'rspec', '1.3.1'
  s.add_development_dependency 'rails', '2.3.8'
  s.add_development_dependency 'rr', '1.0.4'
  
  s.rubyforge_project = s.name
  s.required_rubygems_version = ">= 1.3.4"
end