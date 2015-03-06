# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'add_pod_support/version'

Gem::Specification.new do |spec|
  spec.name          = "add_pod_support"
  spec.version       = AddPodSupport::VERSION
  spec.authors       = ["Sudhir Cirra"]
  spec.email         = ["sudhir@freshdesk.com"]
  spec.summary       = %q{Helper to retrieve details based on the current POD.}
  spec.description   = %q{This helper adds a named_scope 'current_pod' to all models. By default considers 'account_id' column for the filter. Can be overridden using 'pod_filter' method.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
end
