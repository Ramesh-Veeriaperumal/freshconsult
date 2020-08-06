$:.push File.expand_path("../lib", __FILE__)

require "fd_spam_detection_service/version"

Gem::Specification.new do |s|
  s.name        = "fd_spam_detection_service"
  s.version     = FdSpamDetectionService::VERSION
  s.authors     = ["Murugan, Bhavya"]
  s.email       = ["murugu@freshdesk.com, bhavya@freshdesk.com"]
  s.homepage    = "http://freshdesk.com"
  s.summary     = "Freshdesk Spam Detection Service"
  s.description = "Freshdesk Spam Detection Service based on SpamAssassin"

  s.files = Dir["{lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "httparty"

end
