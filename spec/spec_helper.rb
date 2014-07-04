require 'rubygems'
require 'spork'

require 'simplecov'
SimpleCov.start do
  add_filter 'spec/'
  add_filter 'config/'
  add_filter 'test/'
  add_filter 'app/controllers/subscription_admin'
  add_filter 'reports'
  add_filter 'search'

  #add_filter '/vendor/'
  add_group 'mailgun', 'lib/helpdesk/email'
  add_group 'email', 'lib/helpdesk/process_email.rb'
  add_group 'plugins', '/vendor/'
  add_group 'controllers', 'app/controllers'
  add_group 'models', 'app/models'
  add_group 'libs', 'lib/'
  # add_group 'reports', 'reports'
  # add_group 'search', 'search'
end

SimpleCov.coverage_dir 'tmp/coverage'

Spork.prefork do
  # Loading more in this block will cause your tests to run faster. However,
  # if you change any configuration or code from libraries loaded here, you'll
  # need to restart spork for it take effect.

  ENV["RAILS_ENV"] ||= 'test'
  require File.expand_path(File.join(File.dirname(__FILE__),'..','config','environment'))
  require 'spec/autorun'
  require 'spec/rails'
  require 'factory_girl'
  require 'mocha_standalone'
  require 'mocha/object'
  require 'authlogic/test_case'

  # Uncomment the next line to use webrat's matchers
  #require 'webrat/integrations/rspec-rails'

  # Requires supporting files with custom matchers and macros, etc,
  # in ./support/ and its subdirectories.
  Dir[File.expand_path(File.join(File.dirname(__FILE__),'support',  '*.rb'))].each {|f| require f}
  Dir[File.expand_path(File.join(File.dirname(__FILE__),'factories','*.rb'))].each {|f| require f}

 ['spec/support/controller_data_fetcher.rb',
  'spec/support/va/operator_helper/dispatcher.rb',
  'spec/support/va/operator_helper/supervisor.rb',
  'spec/support/va/random_case/action.rb',
  'spec/support/va/random_case/condition/dispatcher.rb',
  'spec/support/va/random_case/condition/supervisor.rb',
  'spec/support/va/random_case/event.rb',
  'spec/support/va/tester.rb',
  'spec/support/va/tester/action.rb',
  'spec/support/va/tester/condition.rb',
  'spec/support/va/tester/condition/dispatcher.rb',
  'spec/support/va/tester/condition/supervisor.rb',
  'spec/support/va/tester/event.rb',
  'spec/support/va/rule_helper.rb',
  'spec/support/va/test_case.rb',
  'spec/support/wf/filter_helper.rb',
  'spec/support/wf/test_case_generator.rb',
  'spec/support/wf/operator_helper.rb',
  'spec/support/wf/option_selector.rb',
  'spec/support/wf/test_case.rb'].each do |file_path| require "#{Rails.root}/#{file_path}" end


  Spec::Runner.configure do |config|
    # If you're not using ActiveRecord you should remove these
    # lines, delete config/database.yml and disable :active_record
    # in your config/boot.rb
    config.use_transactional_fixtures = true
    config.use_instantiated_fixtures  = false
    config.mock_with :mocha
    config.fixture_path = "#{Rails.root}/spec/fixtures/"
    config.include AccountHelper
    config.include AgentHelper
    config.include TicketHelper
    config.include GroupHelper
    config.include TwitterHelper
    config.include SubscriptionHelper
    config.include ForumHelper
    config.include ControllerHelper
    config.include UsersHelper
    config.include SolutionsHelper
    config.include MobihelpHelper
    config.include CompanyHelper
    config.include JiraHelper
    config.include APIHelper, :type => :controller
    config.include SurveyHelper
    config.include CannedResponsesHelper
    config.include AutomationsHelper
    config.include NoteHelper
    config.include RolesHelper
    config.include ApplicationsHelper
    config.include FreshfoneSpecHelper
    config.include APIAuthHelper, :type => :controller
    config.include SlaPoliciesHelper
    config.include ProductsHelper
    config.include WfFilterHelper, :type => :controller
    config.include S3Helper

    config.before(:all) do
      @account = create_test_account
      @agent = get_admin
      @timings = []
    end

    config.before(:each, :type => :controller) do
      @request.host = @account.full_domain
      @request.env['HTTP_REFERER'] = '/sessions/new'
      @request.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36
                                          (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36"
    end

    config.before(:each) do |x|
      name = "#{x.class.description} #{x.description}"
      Rails.logger.info "*"*100
      Rails.logger.info name
      @test_start_time = Time.now
    end

    config.after(:each) do |x|
      name = "#{x.class.description} #{x.description}"
      @test_end_time = Time.now
      @timings.push({
        :name => name,
        :duration => @test_end_time - @test_start_time
      })
      Rails.logger.info "^"*100
    end

    config.after(:all) do |x|
      logfile_name = 'log/rspec_file_times.log'
      logfile = "#{File.dirname(__FILE__)}/../#{logfile_name}"
      file = File.open(logfile, 'a')
      @timings.each do |timing|
        file.write(sprintf("%-150s  -  % 5.3f seconds\n",
                            timing[:name], timing[:duration]))
      end
      file.close
    end

    config.before(:suite) do
      ES_ENABLED = false
      GNIP_ENABLED = false
      DatabaseCleaner.clean_with(:truncation,
                                 {:pre_count => true, :reset_ids => false})
      logfile_name = 'log/rspec_file_times.log'
      logfile = "#{File.dirname(__FILE__)}/../#{logfile_name}"
      File.delete(logfile) if File.exist?(logfile)
    end

    config.after(:suite) do
      Dir["#{Rails.root}/spec/fixtures/files/temp/*"].each do |file|
        File.delete(file) unless file.include?("placeholder.txt")
      end
    end

    #
    # You can declare fixtures for each example_group like this:
    #   describe "...." do
    #     fixtures :table_a, :table_b
    #
    # Alternatively, if you prefer to declare them only once, you can
    # do so right here. Just uncomment the next line and replace the fixture
    # names with your fixtures.
    #
    # config.global_fixtures = :table_a, :table_b
    #
    # If you declare global fixtures, be aware that they will be declared
    # for all of your examples, even those that don't use them.
    #
    # You can also declare which fixtures to use (for example fixtures for test/fixtures):
    #
    # config.fixture_path = Rails.root + '/spec/fixtures/'
    #
    # == Mock Framework
    #
    # RSpec uses its own mocking framework by default. If you prefer to
    # use mocha, flexmock or RR, uncomment the appropriate line:
    #
    # config.mock_with :mocha
    # config.mock_with :flexmock
    # config.mock_with :rr
    #
    # == Notes
    #
    # For more information take a look at Spec::Runner::Configuration and Spec::Runner
  end

end

Spork.each_run do
  # This code will be run each time you run your specs.

end

# --- Instructions ---
# - Sort through your spec_helper file. Place as much environment loading
#   code that you don't normally modify during development in the
#   Spork.prefork block.
# - Place the rest under Spork.each_run block
# - Any code that is left outside of the blocks will be ran during preforking
#   and during each_run!
# - These instructions should self-destruct in 10 seconds.  If they don't,
#   feel free to delete them.
#




# This file is copied to ~/spec when you run 'ruby script/generate rspec'
# from the project root directory.
