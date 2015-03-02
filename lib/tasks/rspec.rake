if Rails.env.test?
  rspec_gem_dir = nil
  Dir["#{Rails.root}/vendor/gems/*"].each do |subdir|
    rspec_gem_dir = subdir if subdir.gsub("#{Rails.root}/vendor/gems/","") =~ /^(\w+-)?rspec-(\d+)/ && File.exist?("#{subdir}/lib/spec/rake/spectask.rb")
  end
  rspec_plugin_dir = File.expand_path(File.dirname(__FILE__) + '/../../vendor/plugins/rspec')

  if rspec_gem_dir && (test ?d, rspec_plugin_dir)
    raise "\n#{'*'*50}\nYou have rspec installed in both vendor/gems and vendor/plugins\nPlease pick one and dispose of the other.\n#{'*'*50}\n\n"
  end

  if rspec_gem_dir
    $LOAD_PATH.unshift("#{rspec_gem_dir}/lib")
  elsif File.exist?(rspec_plugin_dir)
    $LOAD_PATH.unshift("#{rspec_plugin_dir}/lib")
  end

  FacebookTests = [
    "spec/lib/facebook/comment_spec.rb", 
    "spec/lib/facebook/post_spec.rb",
    "spec/lib/facebook/facebook_core_message_spec.rb",
    "spec/lib/facebook/status_spec.rb",
    "spec/controllers/social/facebook_pages_controller_spec.rb",
    "spec/lib/facebook/facebook_core_message_spec.rb",
    "spec/lib/facebook/faceboook_fql_post_spec.rb",
    "spec/lib/facebook/facebook_worker_facebookmessage_spec.rb",
    "spec/lib/facebook/reply_to_comment_spec.rb"
  ]

  GnipTests = [
    "spec/lib/social/gnip/rule_client_spec.rb"
  ]

  XssTests = [
    "spec/lib/xss_spec.rb"
  ]

  TwitterTests = [
    "spec/lib/social/twitter/*_spec.rb", 
    "spec/models/social/twitter_*_spec.rb", 
    "spec/controllers/social/*_spec.rb",
    "spec/controllers/admin/social/*_spec.rb",
    "spec/controllers/mobile/freshsocial/*_spec.rb"
  ]

  ModelTests = [
    "spec/models/helpdesk/agent_spec.rb",
    "spec/models/helpdesk/group_spec.rb",
    "spec/models/helpdesk/mysql_note_spec.rb",
    "spec/models/helpdesk/mysql_ticket_spec.rb",
    "spec/models/helpdesk/ticket_spec.rb"
  ]

  EmailTests = [ 
    "spec/lib/*_email_spec.rb", 
    "spec/lib/email_commands_spec.rb",
    "spec/controllers/email_controller_spec.rb",
    "spec/controllers/mailgun_controller_spec.rb"
  ]

  MobihelpTests = [
    "spec/controllers/support/mobihelp/tickets_controller_spec.rb", 
    "spec/controllers/mobihelp/devices_controller_spec.rb",
    "spec/controllers/mobihelp/solutions_controller_spec.rb",
    "spec/controllers/admin/mobihelp/apps_controller_spec.rb",
    "spec/models/mobihelp/app_spec.rb",
    "spec/controllers/helpdesk/mobihelp_ticket_extras_controller_spec.rb"
  ]

  IntegrationTests = [ 
    "spec/controllers/integrations/gmail_gadgets_controller_spec.rb", 
    "spec/controllers/integrations/google_accounts_controller_spec.rb",
    "spec/controllers/integrations/logmein_controller_spec.rb",
    "spec/controllers/integrations/jira_issue_controller_spec.rb",
    "spec/controllers/integrations/applications_controller_spec.rb",
    "spec/controllers/widgets/feedback_widgets_controller_spec.rb",
    "spec/controllers/sso_controller_spec.rb",
    "spec/controllers/authorizations_controller_spec.rb",
    "spec/controllers/integrations/http_request_proxy_controller_spec.rb",
    "spec/controllers/integrations/installed_applications_controller_spec.rb",
    "spec/controllers/integrations/oauth_util_controller_spec.rb",
    "spec/controllers/integrations/pivotal_tracker_controller_spec.rb",
    "spec/controllers/integrations/user_credentials_controller_spec.rb",
    "spec/controllers/google_login_controller_spec.rb",
    "spec/controllers/google_signup_controller_spec.rb",
    "spec/controllers/integrations/integrated_resources_controller_spec.rb",
    "spec/controllers/api_webhooks_controller_spec.rb",
    "spec/controllers/integrations/slack_controller_spec.rb",
    "spec/controllers/integrations/remote_configurations_controller_spec.rb",
    "spec/lib/integrations/survey_monkey_spec.rb",
    "spec/controllers/integrations/cti/customer_details_controller_spec.rb"
  ]

  FreshfoneTests = [
    "spec/controllers/freshfone/*_spec.rb",
    "spec/lib/freshfone/*_spec.rb",
    "spec/models/freshfone/*_spec.rb"
  ]

  FreshfoneReportsTests = [ 
    "spec/controllers/reports/freshfone/summary_reports_controller_spec.rb"
  ]  

  APITests = [ 
    "spec/controllers/api/json/**/*_spec.rb",
    "spec/controllers/api/xml/**/*_spec.rb"
  ]

  ForumTests = [
    "spec/lib/community/*_spec.rb",
    "spec/lib/community/moderation/*_spec.rb",
    "spec/lib/forum_unpublished_spec.rb",
    "spec/lib/forum_spam_spec.rb",
    "spec/lib/dynamo_spec.rb",
    "spec/controllers/discussions_controller_spec.rb",
    "spec/controllers/discussions/*_spec.rb",
    "spec/controllers/forum_categories_controller_spec.rb",
    "spec/controllers/forums_controller_spec.rb",
    "spec/controllers/topics_controller_spec.rb",
    "spec/models/monitorship_spec.rb",
    "spec/controllers/support/discussions/*_spec.rb",
    "spec/controllers/support/discussions_controller_spec.rb"
  ]

  SolutionTests = [
    "spec/controllers/support/articles_controller_spec.rb",
    "spec/controllers/support/solutions_controller_spec.rb",
    "spec/controllers/support/folders_controller_spec.rb",
    "spec/controllers/helpdesk/solution_articles_controller_spec.rb",
    "spec/controllers/helpdesk/solution_folders_controller_spec.rb",
    "spec/controllers/helpdesk/solution_categories_controller_spec.rb"
  ]

  HelpdeskTests = [ 
    "spec/controllers/accounts_controller_spec.rb",
    "spec/controllers/home_controller_spec.rb",
    "spec/controllers/account_configurations_controller_spec.rb",
    "spec/controllers/agents_controller_spec.rb",
    "spec/controllers/groups_controller_spec.rb",
    "spec/controllers/contacts_controller_spec.rb",
    "spec/controllers/contact_merge_controller_spec.rb",
    "spec/controllers/users_controller_spec.rb",
    "spec/controllers/multiple_user_email_controller_spec.rb",
    "spec/controllers/activations_controller_spec.rb",
    "spec/controllers/customers_controller_spec.rb",
    "spec/controllers/companies_controller_spec.rb",
    "spec/controllers/profiles_controller_spec.rb",
    "spec/controllers/ticket_fields_controller_spec.rb",
    "spec/controllers/admin/contact_fields_controller_spec.rb",
    "spec/controllers/password_resets_controller_spec.rb",
    "spec/controllers/helpdesk/*_spec.rb",
    "spec/controllers/helpdesk/canned_responses/*_spec.rb",
    "spec/controllers/admin/**/*_spec.rb",
    "spec/controllers/support/**/*_spec.rb",
    "spec/controllers/negative/**/*_spec.rb",
    "spec/controllers/wf_filters_controller_spec.rb",
    "spec/controllers/domain_search_controller_spec.rb",
    "spec/controllers/rabbit_mq_controller_spec.rb",
    "spec/models/helpdesk/mysql_*_spec.rb",
    "spec/models/va_rule_spec.rb",
    "spec/lib/webhook_helper_methods_spec.rb",
    "spec/controllers/notification/product_notification_controller_spec.rb",
    "spec/lib/workers/throttler_spec.rb",
    "spec/lib/zen_import_redis_spec.rb",
    "spec/lib/detect_user_language_spec.rb",
    "spec/lib/contacts_import_worker_spec.rb",
    "spec/controllers/solution_uploaded_images_controller_spec.rb",
    "spec/controllers/contact_import_controller_spec.rb",
    "spec/models/flexifield_spec.rb",
    "spec/lib/middleware/api_throttler_spec.rb"
  ]

  MiddlewareSpecs = [
    "spec/lib/middleware/global_restriction_spec.rb",
    "spec/lib/middleware/trusted_ip_spec.rb",
    "spec/lib/spam_watcher_spec.rb"
  ]    

  BillingTests = [
    "spec/controllers/subscriptions_controller_spec.rb",
    "spec/controllers/billing/billing_controller_spec.rb",
    "spec/controllers/partner_admin/affiliates_controller_spec.rb",
    "spec/controllers/admin/day_passes_controller_spec.rb"
  ]       

  FunctionalTests = [
    "spec/lib/gamification/quests/ticket_quest_spec.rb",
    "spec/lib/gamification/quests/process_solution_quests_spec.rb",
    "spec/lib/gamification/quests/process_topic_quests_spec.rb",
    "spec/lib/gamification/quests/process_post_quests_spec.rb",
    "spec/lib/gamification/scores/ticket_and_agent_score_spec.rb"
  ] 

  MobileAppTests = [
    "spec/controllers/mobile/*_spec.rb",
    "spec/controllers/mobile/freshfone/*_spec.rb",
    "spec/controllers/mobile/freshsocial/*_spec.rb"
  ]

  ChatTests = [
    "spec/controllers/chats_controller_spec.rb"
    #"spec/models/chat_setting_spec.rb"
  ]
    
  UnitTests = [ APITests, BillingTests, EmailTests, FacebookTests, ForumTests, FreshfoneTests, FunctionalTests,
                GnipTests, HelpdeskTests,MiddlewareSpecs, MobihelpTests, MobileAppTests, ModelTests, 
                TwitterTests, XssTests, FreshfoneReportsTests, ChatTests]

  UnitTests.flatten!.uniq!

  AllTests = [FacebookTests,UnitTests,TwitterTests,ModelTests,EmailTests, MobihelpTests, IntegrationTests]
  AllTests.flatten!.uniq!

  # Don't load rspec if running "rake gems:*"
  unless ARGV.any? {|a| a =~ /^gems/}

    begin
      require 'spec/rake/spectask'
    rescue MissingSourceFile
      module Spec
        module Rake
          class SpecTask
            def initialize(name)
              task name do
                # if rspec-rails is a configured gem, this will output helpful material and exit ...
                require File.expand_path(File.join(File.dirname(__FILE__),"..","..","config","environment"))

                # ... otherwise, do this:
                raise <<-MSG

                #{"*" * 80}
                *  You are trying to run an rspec rake task defined in
                *  #{__FILE__},
                *  but rspec can not be found in vendor/gems, vendor/plugins or system gems.
                  #{"*" * 80}
                  MSG
              end
            end
          end
        end
      end
    end
    rspec_plugin_dir = File.expand_path(File.dirname(__FILE__) + '/../../vendor/plugins/rspec')

    if rspec_gem_dir && (test ?d, rspec_plugin_dir)
      raise "\n#{'*'*50}\nYou have rspec installed in both vendor/gems and vendor/plugins\nPlease pick one and dispose of the other.\n#{'*'*50}\n\n"
    end

    if rspec_gem_dir
      $LOAD_PATH.unshift("#{rspec_gem_dir}/lib")
    elsif File.exist?(rspec_plugin_dir)
      $LOAD_PATH.unshift("#{rspec_plugin_dir}/lib")
    end

    Rake.application.instance_variable_get('@tasks').delete('default')

    #spec_prereq = File.exist?(File.join(Rails.root, 'config', 'database.yml')) ? "db:test:prepare" : :noop
    spec_prereq = :noop
    task :noop do
    end

    task :default => :spec
    task :stats => "spec:statsetup"

    desc "Run all specs in spec directory (excluding plugin specs)"
    RSpec::Core::RakeTask.new(:spec => spec_prereq) do |t|
      t.rspec_opts = ['--options', "\"#{Rails.root}/spec/spec.opts\""]
      t.pattern = FileList['spec/**/*_spec.rb']
    end

    namespace :spec do
      desc "Run all specs in spec directory with RCov (excluding plugin specs)"

      RSpec::Core::RakeTask.new(:rcov) do |t|
        t.rspec_opts = ['--options', "\"#{Rails.root}/spec/spec.opts\""]
        t.pattern = FileList['spec/**/*_spec.rb']
        t.rcov = true
        t.rcov_opts = lambda do
          IO.readlines("#{Rails.root}/spec/rcov.opts").map {|l| l.chomp.split " "}.flatten
        end
        Rake::Task["db:schema:load".to_sym].invoke
        Rake::Task["db:create_reporting_tables".to_sym].invoke
        Rake::Task["db:create_trigger".to_sym].invoke
        Rake::Task["db:perform_table_partition".to_sym].invoke

        auto_increment_query = "ALTER TABLE shard_mappings AUTO_INCREMENT = #{Time.now.to_i}"
        ActiveRecord::Base.connection.execute(auto_increment_query)
      end

      desc "Print Specdoc for all specs (excluding plugin specs)"
      RSpec::Core::RakeTask.new(:doc) do |t|
        t.rspec_opts = ["--format", "specdoc", "--dry-run"]
        t.pattern = FileList['spec/**/*_spec.rb']
      end

      desc "Print Specdoc for all plugin examples"
      RSpec::Core::RakeTask.new(:plugin_doc) do |t|
        t.rspec_opts = ["--format", "specdoc", "--dry-run"]
        t.pattern = FileList['vendor/plugins/**/spec/**/*_spec.rb'].exclude('vendor/plugins/rspec/*')
      end

      [:models, :controllers, :views, :helpers, :lib, :integration].each do |sub|
        desc "Run the code examples in spec/#{sub}"
        RSpec::Core::RakeTask.new(sub => spec_prereq) do |t|
          t.rspec_opts = ['--options', "\"#{Rails.root}/spec/spec.opts\""]
          t.pattern = FileList["spec/#{sub}/**/*_spec.rb"]
        end
      end

      desc "Run the code examples in vendor/plugins (except RSpec's own)"
      RSpec::Core::RakeTask.new(:plugins => spec_prereq) do |t|
        t.rspec_opts = ['--options', "\"#{Rails.root}/spec/spec.opts\""]
        t.pattern = FileList['vendor/plugins/**/spec/**/*_spec.rb'].exclude('vendor/plugins/rspec/*').exclude("vendor/plugins/rspec-rails/*")
      end

      namespace :plugins do
        desc "Runs the examples for rspec_on_rails"
        RSpec::Core::RakeTask.new(:rspec_on_rails) do |t|
          t.rspec_opts = ['--options', "\"#{Rails.root}/spec/spec.opts\""]
          t.pattern = FileList['vendor/plugins/rspec-rails/spec/**/*_spec.rb']
        end
      end

      # Setup specs for stats
      task :statsetup do
        require 'code_statistics'
        ::STATS_DIRECTORIES << %w(Model\ specs spec/models) if File.exist?('spec/models')
        ::STATS_DIRECTORIES << %w(View\ specs spec/views) if File.exist?('spec/views')
        ::STATS_DIRECTORIES << %w(Controller\ specs spec/controllers) if File.exist?('spec/controllers')
        ::STATS_DIRECTORIES << %w(Helper\ specs spec/helpers) if File.exist?('spec/helpers')
        ::STATS_DIRECTORIES << %w(Library\ specs spec/lib) if File.exist?('spec/lib')
        ::STATS_DIRECTORIES << %w(Routing\ specs spec/routing) if File.exist?('spec/routing')
        ::STATS_DIRECTORIES << %w(Integration\ specs spec/integration) if File.exist?('spec/integration')
        ::CodeStatistics::TEST_TYPES << "Model specs" if File.exist?('spec/models')
        ::CodeStatistics::TEST_TYPES << "View specs" if File.exist?('spec/views')
        ::CodeStatistics::TEST_TYPES << "Controller specs" if File.exist?('spec/controllers')
        ::CodeStatistics::TEST_TYPES << "Helper specs" if File.exist?('spec/helpers')
        ::CodeStatistics::TEST_TYPES << "Library specs" if File.exist?('spec/lib')
        ::CodeStatistics::TEST_TYPES << "Routing specs" if File.exist?('spec/routing')
        ::CodeStatistics::TEST_TYPES << "Integration specs" if File.exist?('spec/integration')
      end

      namespace :db do
        namespace :fixtures do
          desc "Load fixtures (from spec/fixtures) into the current environment's database.  Load specific fixtures using FIXTURES=x,y. Load from subdirectory in test/fixtures using FIXTURES_DIR=z."
          task :load => :environment do
            ActiveRecord::Base.establish_connection(Rails.env)
            base_dir = File.join(Rails.root, 'spec', 'fixtures')
            fixtures_dir = ENV['FIXTURES_DIR'] ? File.join(base_dir, ENV['FIXTURES_DIR']) : base_dir

            require 'active_record/fixtures'
            (ENV['FIXTURES'] ? ENV['FIXTURES'].split(/,/).map {|f| File.join(fixtures_dir, f) } : Dir.glob(File.join(fixtures_dir, '*.{yml,csv}'))).each do |fixture_file|
              Fixtures.create_fixtures(File.dirname(fixture_file), File.basename(fixture_file, '.*'))
            end
          end
        end

        task :reset do
          require 'faker'
          require 'simplecov'
          require 'active_record'
          # load 'Rakefile'
          config = YAML::load(IO.read(File.join(Rails.root, 'config/database.yml')))
          ActiveRecord::Base.establish_connection(config["test"])
          ActiveRecord::Migration.create_table "subscription_plans", :force => true do |t|
            t.string   "name"
            t.decimal  "amount",          :precision => 10, :scale => 2
            t.datetime "created_at"
            t.datetime "updated_at"
            t.integer  "renewal_period",                                 :default => 1
            t.decimal  "setup_amount",    :precision => 10, :scale => 2
            t.integer  "trial_period",                                   :default => 1
            t.integer  "free_agents"
            t.decimal  "day_pass_amount", :precision => 10, :scale => 2
            t.boolean  "classic",                                        :default => false
            t.text     "price"
          end
          Rake::Task["db:schema:load".to_sym].invoke
          Rake::Task["db:create_reporting_tables".to_sym].invoke
          Rake::Task["db:create_trigger".to_sym].invoke
          Rake::Task["db:perform_table_partition".to_sym].invoke
        end
      end

      namespace :helpdesk do
        desc "Runs all helpdesk tests"
        RSpec::Core::RakeTask.new(:all) do |t|
          t.rspec_opts = ['--options', "\"#{Rails.root}/spec/spec.opts\""]
          t.pattern = FileList.new(HelpdeskTests)
        end
      end    

      namespace :social do
        desc "Runs all twitter tests"
        RSpec::Core::RakeTask.new(:twitter) do |t|
          t.rspec_opts = ['--options', "\"#{Rails.root}/spec/spec.opts\""]
          t.pattern = FileList.new(TwitterTests+GnipTests)
        end

        RSpec::Core::RakeTask.new(:facebook) do |t|
          t.rspec_opts = ['--options', "\"#{Rails.root}/spec/spec.opts\""]
          t.pattern = FileList.new(FacebookTests)
        end
      end    

      namespace :freshfone do
        desc "Running all Freshfone Testss"
        RSpec::Core::RakeTask.new(:all) do |t|
          t.rspec_opts = ['--options', "\"#{Rails.root}/spec/spec.opts\""]
          t.pattern = FileList.new(FreshfoneTests)
        end
      end    

      namespace :freshchat do
        desc "Running all FreshChat Tests"
        RSpec::Core::RakeTask.new(:all) do |t|
          t.rspec_opts = ['--options', "\"#{Rails.root}/spec/spec.opts\""]
          t.pattern = FileList.new(ChatTests)
        end
      end      

      namespace :freshfone_reports do
        desc "Running all freshfone summary reports tests"
        RSpec::Core::RakeTask.new(:all) do |t|
          t.rspec_opts = ['--options', "\"#{Rails.root}/spec/spec.opts\""]
          t.pattern = FileList.new(FreshfoneReportsTests)
        end
      end

      namespace :unit_tests do
        desc "Running all integration tests"
        Rake::Task["spec:db:reset".to_sym].invoke if Rails.env.test?
        RSpec::Core::RakeTask.new(:all) do |t|
          t.rspec_opts = ['--options', "\"#{Rails.root}/spec/spec.opts\""]
          t.pattern = FileList.new(UnitTests).uniq
        end
      end

      namespace :email_tests do
        desc "Running all email tests"
        Rake::Task["spec:db:reset".to_sym].invoke if Rails.env.test?
        RSpec::Core::RakeTask.new(:all) do |t|
          t.rspec_opts = ['--options', "\"#{Rails.root}/spec/spec.opts\""]
          t.pattern = FileList.new(EmailTests)
        end
      end

      namespace :forum_tests do
        desc "Running all forum tests"
        Rake::Task["spec:db:reset".to_sym].invoke if Rails.env.test?
        RSpec::Core::RakeTask.new(:all) do |t|
          t.rspec_opts = ['--options', "\"#{Rails.root}/spec/spec.opts\""]
          t.pattern = FileList.new(ForumTests)
        end
      end


      namespace :integrations do
        desc "Running all freshdesk integrations tests"
        RSpec::Core::RakeTask.new(:all) do |t|
          t.rspec_opts = ['--options', "\"#{Rails.root}/spec/spec.opts\""]
          t.pattern = FileList.new(IntegrationTests)
        end
      end

      namespace :mobihelp do
        desc "Running all mobihelp tests"
        RSpec::Core::RakeTask.new(:all) do |t|
          t.rspec_opts = ['--options', "\"#{Rails.root}/spec/spec.opts\""]
          t.pattern = FileList.new(MobihelpTests)
        end
      end

      namespace :mobile do
        desc "Running all Mobile app tests"
        RSpec::Core::RakeTask.new(:all) do |t|
          t.rspec_opts = ['--options', "\"#{Rails.root}/spec/spec.opts\""]
          t.pattern = FileList.new(MobileAppTests)
        end
      end

      namespace :community_tests do
        desc "Running all community tests"
        Rake::Task["spec:db:reset".to_sym].invoke if Rails.env.test?
        RSpec::Core::RakeTask.new(:all) do |t|
          t.rspec_opts = ['--options', "\"#{Rails.root}/spec/spec.opts\""]
          t.pattern = FileList.new(ForumTests+SolutionTests).uniq
        end
      end
      
      namespace :api do
        desc "Running all api tests"
        RSpec::Core::RakeTask.new(:all) do |t|
          t.rspec_opts = ['--options', "\"#{Rails.root}/spec/spec.opts\""]
          t.pattern = FileList.new(APITests)
        end
      end

      namespace :all do
        desc "Running all the tests"
        RSpec::Core::RakeTask.new(:tests) do |t|
          t.rspec_opts = ['--options', "\"#{Rails.root}/spec/spec.opts\""]
          t.pattern = FileList.new(AllTests)
        end

        RSpec::Core::RakeTask.new(:model) do |t|
          t.rspec_opts = ['--options', "\"#{Rails.root}/spec/spec.opts\""]
          t.pattern = FileList.new(ModelTests)
        end
      end
    end
  end
end
