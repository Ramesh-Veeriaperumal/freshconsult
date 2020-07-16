$:.push File.expand_path("../lib", __FILE__)
Gem::Specification.new do |s|
  s.name        = "custom_fields"
  s.version     = "0.1"
  s.platform    = Gem::Platform::CURRENT

  s.authors     = ["Arvind Ravindran", "Hariharan Ganapathiraman", "Akila Anbazhagan"]
  s.email       = ["arvind@freshdesk.com", "hariharan@freshdesk.com", "akila@freshdesk.com"]

  s.summary     = "Custom Fields for any Rails Model"
  s.description = "Custom Fields for any Rails Model. Rails like has_many association methods and
                   inherits_model conventions for adding methods and functionality to the model.
                   Pass the Right Specifications as Args and you're All Done!"

  s.require_paths = ['lib','app']
  s.files = Dir["{app,lib}/**/*"]  

  s.add_runtime_dependency 'rails', '~> 3.2.18'
  s.add_runtime_dependency 'acts_as_list', '0.1.4'
end