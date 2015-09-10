module SimpleCovSetup
  require 'simplecov'
  require 'simplecov-csv'
  require 'simplecov-rcov'

  SimpleCov.start do
    add_filter SimpleCov::StringFilter.new("^((?!#{root}/api\/).)*$")

    add_group 'api', 'api/'
    add_group 'apiconcerns', 'api/app/controllers/concerns'
    add_group 'apivalidations', 'api/app/controllers/validations'
    add_group 'apicontrollers', 'api/app/controllers'
    add_group 'apilib', 'api/lib'
  end

  SimpleCov.coverage_dir 'tmp/coverage'

  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::CSVFormatter,
    SimpleCov::Formatter::RcovFormatter,
  ]
end

include SimpleCovSetup
