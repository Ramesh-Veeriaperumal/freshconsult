module SimpleCovSetup
  require 'simplecov'
  require 'simplecov-csv'
  require 'simplecov-rcov'
  require 'codecov'

  require "#{Dir.pwd}/test/api/helpers/boc_groups.rb"

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
  #
  DIR_PATH = "#{Dir.pwd}/".freeze

  GROUP_FILE_MAP = {
    'ateam' => BocGroups::ATEAM_FILES,
    'autobots' => BocGroups::AUTOBOTS_FILES,
    'falcons' => BocGroups::FALCONS_FILES,
    'gonein10' => BocGroups::G10_FILES,
    'infinity' => BocGroups::INFINITY_FILES,
    'ninjas' => BocGroups::NINJAS_FILES,
    'suicidesquad' => BocGroups::SUICIDESQUAD_FILES,
    'shadowfax' => BocGroups::SHADOWFAX_FILES,
    'wildcards' => BocGroups::WILDCARDS_FILES,
    'others' => BocGroups::OTHERS_FILES,
    'common' => BocGroups::COMMON_FILES
  }.freeze

  SimpleCov.start do
    # Adding exact filters
    add_filter 'app/mailers'
    add_filter 'app/controllers/helpdesk'
    add_filter 'app/controllers/integrations'
    add_filter 'app/controllers/freshfone'
    add_filter 'app/helpers/freshfone'

    add_filter SimpleCov::StringFilter.new("^((?!#{root}/(api|lib|app\/models|app\/workers|app\/observers|app\/drops|app\/helpers)\/).)*$")
    # add_filter SimpleCov::StringFilter.new("^((?!#{root}/app\/workers).)*$")
    # add_filter SimpleCov::StringFilter.new("^((?!#{root}/app\/observers).)*$")
    # add_filter SimpleCov::StringFilter.new("^((?!#{root}/app\/mailers).)*$")
    # add_filter SimpleCov::StringFilter.new("^((?!#{root}/lib\/).)*$")

    # TODO: remove app/controllers and continue including api/app/controllers and app/controllers/admin

    add_filter  'spec/'
    add_filter  'config/'
    add_filter  'test/'
    add_filter  'fdadmin'
    add_filter  'vendor/gems'

    GROUP_FILE_MAP.each do |group, filelist|
      add_group group do |src_file|
        file_name = src_file.filename.gsub(DIR_PATH, '')
        filelist.include?(file_name)
      end
    end

    add_group 'api', 'api/'
    add_group 'apiconcerns', 'api/app/controllers/concerns'
    add_group 'apivalidations', 'api/app/controllers/validations'
    add_group 'apicontrollers', 'api/app/controllers'
    add_group 'apilib', 'api/lib'
    add_group 'lib', 'lib'
    add_group 'sandbox', 'lib/sync/'
    add_group 'appmodels', 'app/models'
    add_group 'webadmin', 'app/controllers/admin'
    add_group 'webcontrollers', 'app/controllers'
    add_group 'appworkers', 'app/workers'
    add_group 'appmailers', 'app/mailers'
    add_group 'appobservers', 'app/observers'
    add_group 'appdrops', 'app/drops'
    add_group 'apphelpers', 'app/helpers'
  end

  SimpleCov.coverage_dir 'tmp/coverage'
  SimpleCov.command_name "rails_app_#{$$}"
  SimpleCov.merge_timeout 3600 # 1 hour


  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::CSVFormatter,
    SimpleCov::Formatter::RcovFormatter,
    SimpleCov::Formatter::Codecov
  ]
end

include SimpleCovSetup
