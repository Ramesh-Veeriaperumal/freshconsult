require 'simplecov'
require 'simplecov-csv'
require 'simplecov-rcov'
require 'codecov'
require "#{Dir.pwd}/test/api/helpers/boc_groups.rb"

module SimpleCovSetup
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

  # Pls consult Jey to delete the following files from the codebase - POSSIBLE_DEAD_CODE & DEAD_CODE

  POSSIBLE_DEAD_CODE = ['api/app/delegators/dashboard_delegator.rb'].freeze

  DEAD_CODE = [
    'lib/password.rb',
    'lib/crm/salesforce.rb',
    'lib/import/forums.rb',
    'lib/import/zendesk_data.rb',
    'app/controllers/support/search_controller.rb',
    'app/controllers/search/search_controller.rb'
  ].freeze

  IGNORE_FILES = %w[lib/attachment_helper.rb lib/meta_data_check/meta_data_check_methods.rb
                    lib/guid.rb lib/freshops_tools_worker_methods.rb app/drops lib/helpdesk/send_and_set_helper.rb
                    lib/freshfone].freeze

  IGNORE_FILES_SECONDARY_APP_HELPERS = %w[lib/portal/portal_filters.rb lib/portal/helpers/discussions_helper.rb
                    lib/portal/helpers/discussions_voting_helper.rb lib/portal/helpers/article.rb
                    lib/meta_helper_methods.rb lib/auth/google_login_authenticator.rb lib/forum_helper_methods.rb
                    lib/confirm_delete_helper.rb lib/rtl_helper.rb lib/community_helper.rb lib/tab_helper.rb
                    lib/store_helper.rb lib/json_escape.rb lib/community/monitorship_helper.rb lib/solution/cache.rb].freeze

  IGNORE_FILES_SECONDARY_APP_MAILERS = %w[lib/community/mailer_helper.rb]

  IGNORE_FILES_APP_CONTROLLERS_HELPDESK = %w[lib/dashboard_controller_methods.rb lib/dashboard/elastic_search_methods.rb
                                             lib/helpdesk/merge_ticket_actions.rb lib/shared_personal_methods.rb
                                             lib/helpdesk/adjacent_tickets.rb lib/ticket_validation_methods.rb].freeze

  IGNORE_FILES_APP_CONTROLLERS_INTEGRATIONS = %w[lib/integrations/dynamicscrm/crm_util.rb lib/integrations/dynamicscrm/api_util.rb
                                             lib/integrations/controller_methods.rb lib/integrations/infusionsoft/infusionsoft_util.rb
                                             lib/integrations/office365/auth_helper.rb lib/integrations/remote_configurations/seoshop.rb
                                             lib/integrations/sugarcrm/api_util.rb].freeze

  def self.start_simplecov
    SimpleCov.start do
      # Adding exact filters
      add_filter 'app/mailers'
      add_filter 'app/controllers/helpdesk'
      add_filter 'app/controllers/integrations'
      add_filter 'app/controllers/freshfone'
      add_filter 'app/helpers/freshfone'

      add_filter SimpleCov::StringFilter.new("^((?!#{root}/(api|lib|app\/models|app\/workers|app\/observers|app\/drops|app\/helpers)\/).)*$")

      add_filter 'spec/'
      add_filter 'config/'
      add_filter 'test/'
      add_filter 'fdadmin'
      add_filter 'vendor/gems'

      # Revisit again
      add_filter  'app/helpers'

      POSSIBLE_DEAD_CODE.each do |file|
        add_filter file
      end

      DEAD_CODE.each do |file|
        add_filter file
      end

      IGNORE_FILES.each do |file|
        add_filter file
      end

      IGNORE_FILES_SECONDARY_APP_HELPERS.each do |file|
        add_filter file
      end

      IGNORE_FILES_SECONDARY_APP_MAILERS.each do |file|
        add_filter file
      end

      IGNORE_FILES_APP_CONTROLLERS_HELPDESK.each do |file|
        add_filter file
      end

      IGNORE_FILES_APP_CONTROLLERS_INTEGRATIONS.each do |file|
        add_filter file
      end

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

    coverage_directory = ENV.fetch('COVERAGE_DIR', 'tmp/coverage')
    SimpleCov.coverage_dir coverage_directory

    if !defined?($local_dev_testing) || $local_dev_testing != true
      SimpleCov.command_name "rails_app_#{$$}#{Random.rand(10...9999).to_s}"
      SimpleCov.merge_timeout 3600 # 1 hour
    else
      SimpleCov.command_name "local_dev_testing"
      SimpleCov.merge_timeout 20
    end

    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::CSVFormatter,
      SimpleCov::Formatter::RcovFormatter,
      SimpleCov::Formatter::Codecov
    ]
  end
end

puts 'Starting SimpleCovSetup'
SimpleCovSetup.start_simplecov

if ENV["COVERAGE_FILES"] != nil
  coverage_files = ENV["COVERAGE_FILES"].split(',')
  coverage_files.each do |file|
    file_full_path = Dir.pwd + '/' + file
    puts "Loading #{file_full_path} for coverage"
    load file_full_path
  end
end
