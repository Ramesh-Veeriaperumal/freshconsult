gem 'test-unit', '1.2.3' if RUBY_VERSION.to_f >= 1.9
rspec_gem_dir = nil
Dir["#{RAILS_ROOT}/vendor/gems/*"].each do |subdir|
  rspec_gem_dir = subdir if subdir.gsub("#{RAILS_ROOT}/vendor/gems/","") =~ /^(\w+-)?rspec-(\d+)/ && File.exist?("#{subdir}/lib/spec/rake/spectask.rb")
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
  "spec/lib/facebook/post_spec.rb"
]

TwitterTests = [
  "spec/lib/social/twitter/*_spec.rb", 
  "spec/models/social/twitter_*_spec.rb", 
  "spec/controllers/social/*_spec.rb",
  "spec/controllers/admin/social/*_spec.rb"
]

ModelTests = ["spec/models/helpdesk/*_spec.rb"]

EmailTests = [ 
  "spec/lib/*_email_spec.rb", 
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
  "spec/controllers/sso_controller_spec.rb"
]

FreshfoneTests = [
  "spec/controllers/freshfone/*_spec.rb",
  "spec/lib/freshfone/*_spec.rb"
]

APITests = [ 
  "spec/controllers/api/json/*_spec.rb",
  "spec/controllers/api/xml/*_spec.rb"
]

ForumTests = [
  "spec/controllers/discussions_controller_spec.rb",
  "spec/controllers/discussions/*_spec.rb"
]

HelpdeskTests = [ 
  "spec/controllers/agents_controller_spec.rb",
  "spec/controllers/groups_controller_spec.rb",
  "spec/controllers/contacts_controller_spec.rb",
  "spec/controllers/contact_merge_controller_spec.rb",
  "spec/controllers/users_controller_spec.rb",
  "spec/controllers/user_emails_controller_spec.rb",
  "spec/controllers/activations_controller_spec.rb",
  "spec/controllers/customers_controller_spec.rb",
  "spec/controllers/profiles_controller_spec.rb",
  "spec/controllers/ticket_fields_controller_spec.rb",
  "spec/controllers/password_resets_controller_spec.rb",
  "spec/controllers/helpdesk/*_spec.rb",
  "spec/controllers/admin/**/*_spec.rb",
  "spec/controllers/support/**/*_spec.rb",
  "spec/controllers/negative/**/*_spec.rb",
  "spec/controllers/wf_filters_controller_spec.rb",
  "spec/models/helpdesk/mysql_*_spec.rb",
  "spec/models/va_rule_spec.rb"
]    

BillingTests = [
  "spec/controllers/subscriptions_controller_spec.rb",
  "spec/controllers/billing/billing_controller_spec.rb",
  "spec/controllers/partner_admin/affiliates_controller_spec.rb"
]        
  
UnitTests = [ FacebookTests, TwitterTests, EmailTests, MobihelpTests, IntegrationTests, FreshfoneTests, 
              APITests, ForumTests, HelpdeskTests, BillingTests ]
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

  Rake.application.instance_variable_get('@tasks').delete('default')

  #spec_prereq = File.exist?(File.join(RAILS_ROOT, 'config', 'database.yml')) ? "db:test:prepare" : :noop
  spec_prereq = :noop
  task :noop do
  end

  task :default => :spec
  task :stats => "spec:statsetup"

  desc "Run all specs in spec directory (excluding plugin specs)"
  Spec::Rake::SpecTask.new(:spec => spec_prereq) do |t|
    t.spec_opts = ['--options', "\"#{RAILS_ROOT}/spec/spec.opts\""]
    t.spec_files = FileList['spec/**/*_spec.rb']
  end

  namespace :spec do
    desc "Run all specs in spec directory with RCov (excluding plugin specs)"

    Spec::Rake::SpecTask.new(:rcov) do |t|
      t.spec_opts = ['--options', "\"#{RAILS_ROOT}/spec/spec.opts\""]
      t.spec_files = FileList['spec/**/*_spec.rb']
      t.rcov = true
      t.rcov_opts = lambda do
        IO.readlines("#{RAILS_ROOT}/spec/rcov.opts").map {|l| l.chomp.split " "}.flatten
      end
    end

    desc "Print Specdoc for all specs (excluding plugin specs)"
    Spec::Rake::SpecTask.new(:doc) do |t|
      t.spec_opts = ["--format", "specdoc", "--dry-run"]
      t.spec_files = FileList['spec/**/*_spec.rb']
    end

    desc "Print Specdoc for all plugin examples"
    Spec::Rake::SpecTask.new(:plugin_doc) do |t|
      t.spec_opts = ["--format", "specdoc", "--dry-run"]
      t.spec_files = FileList['vendor/plugins/**/spec/**/*_spec.rb'].exclude('vendor/plugins/rspec/*')
    end

    [:models, :controllers, :views, :helpers, :lib, :integration].each do |sub|
      desc "Run the code examples in spec/#{sub}"
      Spec::Rake::SpecTask.new(sub => spec_prereq) do |t|
        t.spec_opts = ['--options', "\"#{RAILS_ROOT}/spec/spec.opts\""]
        t.spec_files = FileList["spec/#{sub}/**/*_spec.rb"]
      end
    end

    desc "Run the code examples in vendor/plugins (except RSpec's own)"
    Spec::Rake::SpecTask.new(:plugins => spec_prereq) do |t|
      t.spec_opts = ['--options', "\"#{RAILS_ROOT}/spec/spec.opts\""]
      t.spec_files = FileList['vendor/plugins/**/spec/**/*_spec.rb'].exclude('vendor/plugins/rspec/*').exclude("vendor/plugins/rspec-rails/*")
    end

    namespace :plugins do
      desc "Runs the examples for rspec_on_rails"
      Spec::Rake::SpecTask.new(:rspec_on_rails) do |t|
        t.spec_opts = ['--options', "\"#{RAILS_ROOT}/spec/spec.opts\""]
        t.spec_files = FileList['vendor/plugins/rspec-rails/spec/**/*_spec.rb']
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
        load 'Rakefile'
        config = YAML::load(IO.read(File.join(RAILS_ROOT, 'config/database.yml')))
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

    namespace :social do
      desc "Runs all twitter tests"
      Spec::Rake::SpecTask.new(:twitter) do |t|
        t.spec_opts = ['--options', "\"#{RAILS_ROOT}/spec/spec.opts\""]
        t.spec_files = FileList.new(TwitterTests)
      end

      Spec::Rake::SpecTask.new(:facebook) do |t|
        t.spec_opts = ['--options', "\"#{RAILS_ROOT}/spec/spec.opts\""]
        t.spec_files = FileList.new(FacebookTests)
      end
    end

    namespace :freshfone do
      desc "Running all Freshfone Testss"
      Spec::Rake::SpecTask.new(:all) do |t|
        t.spec_opts = ['--options', "\"#{RAILS_ROOT}/spec/spec.opts\""]
        t.spec_files = FileList.new(FreshfoneTests)
      end
    end    

    namespace :unit_tests do
      desc "Running all integration tests"
      Rake::Task["spec:db:reset".to_sym].invoke if Rails.env.test?
      Spec::Rake::SpecTask.new(:all) do |t|
        t.spec_opts = ['--options', "\"#{RAILS_ROOT}/spec/spec.opts\""]
        t.spec_files = FileList.new(UnitTests)
      end
    end

    namespace :email_tests do
      desc "Running all email tests"
      Rake::Task["spec:db:reset".to_sym].invoke if Rails.env.test?
      Spec::Rake::SpecTask.new(:all) do |t|
        t.spec_opts = ['--options', "\"#{RAILS_ROOT}/spec/spec.opts\""]
        t.spec_files = FileList.new(EmailTests)
      end
    end

    namespace :integrations do
      desc "Running all freshdesk integrations tests"
      Spec::Rake::SpecTask.new(:all) do |t|
        t.spec_opts = ['--options', "\"#{RAILS_ROOT}/spec/spec.opts\""]
        t.spec_files = FileList.new(IntegrationTests)
      end
    end

    namespace :mobihelp do
      desc "Running all mobihelp tests"
      Spec::Rake::SpecTask.new(:all) do |t|
        t.spec_opts = ['--options', "\"#{RAILS_ROOT}/spec/spec.opts\""]
        t.spec_files = FileList.new(MobihelpTests)
      end
    end
    
    namespace :api do
      desc "Running all api tests"
      Spec::Rake::SpecTask.new(:all) do |t|
        t.spec_opts = ['--options', "\"#{RAILS_ROOT}/spec/spec.opts\""]
        t.spec_files = FileList.new(APITests)
      end
    end

    namespace :all do
      desc "Running all the tests"
      Spec::Rake::SpecTask.new(:tests) do |t|
        t.spec_opts = ['--options', "\"#{RAILS_ROOT}/spec/spec.opts\""]
        t.spec_files = FileList.new(AllTests)
      end

      Spec::Rake::SpecTask.new(:model) do |t|
        t.spec_opts = ['--options', "\"#{RAILS_ROOT}/spec/spec.opts\""]
        t.spec_files = FileList.new(ModelTests)
      end
    end

  end
end
