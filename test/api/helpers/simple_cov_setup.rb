module SimpleCovSetup
  require 'simplecov'
  require 'simplecov-csv'
  require 'simplecov-rcov'

  # Simplecov does not show files with 0% coverage that are not eagerloaded. Hence including them.
  # all_files = Dir['api/lib/*.rb'] + Dir['api/app/delegators/*.rb']
  # base_result = {}
  # all_files.each do |file|
  #   absolute = File::expand_path(file)
  #   lines = File.readlines(absolute, :encoding => 'UTF-8')
  #   base_result[absolute] = lines.map do |l|
  #     l.strip!
  #     l.empty? || l =~ /^end$/ || l[0] == '#' ? nil : 0
  #   end
  # end

  # SimpleCov.at_exit do
  #   merged = SimpleCov.result.original_result.merge_resultset(base_result)
  #   result = SimpleCov::Result.new(merged)
  #   result.command_name = SimpleCov.result.command_name
  #   result.format!
  # end

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
