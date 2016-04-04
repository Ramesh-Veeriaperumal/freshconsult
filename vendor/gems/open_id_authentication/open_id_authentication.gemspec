$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
name = "open_id_authentication"
require "#{name}/version"

Gem::Specification.new name, OpenIdAuthentication::VERSION do |s|
  s.summary = "open_id_authentication provides a thin wrapper around the excellent rack-openid gem."
  s.authors = ["Patrick Robertson", "Michael Grosser"]
  s.email = "michael@grosser.it"
  s.homepage = "https://github.com/grosser/#{name}"
  s.files = `git ls-files`.split("\n")
  s.license = "MIT"
  s.add_runtime_dependency "rack-openid", ">= 0.2.1"
end