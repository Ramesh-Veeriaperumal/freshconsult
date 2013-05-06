# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{features}
  s.version = "1.0.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Mick Staugaard", "Morten Primdahl"]
  s.date = %q{2009-07-29}
  s.email = %q{mick@zendesk.com}
  s.extra_rdoc_files = [
    "README.rdoc"
  ]
  s.files = [
    ".gitignore",
     "README.rdoc",
     "Rakefile",
     "VERSION",
     "features.gemspec",
     "lib/features.rb",
     "lib/features/active_record_extension.rb",
     "lib/features/feature.rb",
     "lib/features/features_helper.rb",
     "test/database.yml",
     "test/features_test.rb",
     "test/fixtures/accounts.yml",
     "test/fixtures/features.yml",
     "test/schema.rb",
     "test/test_helper.rb"
  ]
  s.homepage = %q{http://github.com/zendesk/features}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{Features is a nice little gem for associating application features with an active record model in a Rails app}
  s.test_files = [
    "test/features_test.rb",
     "test/schema.rb",
     "test/test_helper.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
