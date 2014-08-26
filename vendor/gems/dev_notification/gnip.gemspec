# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{dev_notification}
  s.version = "1.0.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Revathi, Arvind"]
  s.date = %q{2009-07-29}
  s.email = %q{revathi@freshdesk.com, arvind@freshdesk.com}
  s.extra_rdoc_files = [
    "README.rdoc"
  ]
  s.files = Dir["{app,config,db,lib}/**/*"] + ["Rakefile", "README.rdoc"]
  s.homepage = %q{http://github.com/freshdesk/dev_notification}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{create sns and sqs queues}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
