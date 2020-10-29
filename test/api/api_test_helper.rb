# https://confluence.freshworks.com/display/FDCORE/BaseTestHelper+for+BE+Unit+Tests

require_relative '../base_test_helper.rb'
require_relative 'helpers/test_files.rb'
require 'sidekiq/testing'

class ActionController::TestCase
  self.use_transactional_fixtures = true

  rescue_from AWS::DynamoDB::Errors::ResourceNotFoundException do |exception|
    Rake::Task['forum_moderation:create_tables'].invoke(Time.zone.now.year, Time.zone.now.month) if Rails.env.test?
    Rake::Task['forum_moderation:create_tables'].invoke(Time.zone.now.year, (Time.zone.now.month + 1)) if Rails.env.test?
  end
  @@setup_stub = false
  # awk '/START <test_method_name>/,/END <test_method_name>/' log/test.log
  # Eg: awk '/START test_agent_filter_state/,/END test_agent_filter_state/' log/test.log
  def initialize(name = nil)
    @test_name = name
    super(name) unless name.nil?
  end

  def setup
    $redis_others.flushall # redis cleanup
    WebMock.disable_net_connect! # disabling Webmock

    $redis_others.set('NEW_SIGNUP_ENABLED', 1)
    begin_gc_deferment
    activate_authlogic
    get_agent
    @account.make_current
    user = User.first.make_current
    create_session
    set_request_params
    set_key(account_key, 1000, nil)
    set_key(default_key, 100, nil)
    # Enabling Private API
    @account.launch(:falcon)
    @account.add_feature(:falcon)
    if @account.reputation != 1
      @account.reputation = 1
      @account.save
    end
    setup_stub

    Rails.logger.debug "START #{@test_name}"
  end

  def setup_stub
    return if @@setup_stub

    # To prevent DynamoDB errors.
    SpamCounter.stubs(:count).returns(0)
    Helpdesk::Attachment.any_instance.stubs(:save_attached_files).returns(true)
    Helpdesk::Attachment.any_instance.stubs(:prepare_for_destroy).returns(true)
    Helpdesk::Attachment.any_instance.stubs(:destroy_attached_files).returns(true)

    #Stub all memcache calls
    Dalli::Client.any_instance.stubs(:get).returns(nil)
    Dalli::Client.any_instance.stubs(:delete).returns(true)
    Dalli::Client.any_instance.stubs(:set).returns(true)
    @@setup_stub = true
  end

  def teardown
    reconsider_gc_deferment
    @controller.instance_variables.each do |ivar|
      @controller.instance_variable_set(ivar, nil)
    end
    super
    clear_instance_variables

    Rails.logger.debug "END #{@test_name}"
  end
end

class ActionDispatch::IntegrationTest
  self.use_transactional_fixtures = true

  rescue_from AWS::DynamoDB::Errors::ResourceNotFoundException do |exception|
    Rake::Task['forum_moderation:create_tables'].invoke(Time.zone.now.year, Time.zone.now.month) if Rails.env.test?
    Rake::Task['forum_moderation:create_tables'].invoke(Time.zone.now.year, (Time.zone.now.month + 1)) if Rails.env.test?
  end

  # For logging query details in a separate folder
  FileUtils.mkdir_p "#{Rails.root}/test/api/query_reports"

  def initialize(name = nil)
    @test_name = name
    super(name) unless name.nil?
  end

  def setup
    $redis_others.flushall # redis cleanup
    WebMock.disable_net_connect! # disabling Webmock

    begin_gc_deferment
    activate_authlogic
    get_agent
    set_request_headers
    host!('localhost.freshpo.com')
    set_key(account_key, 500, nil)
    set_key(default_key, 400, nil)
    @account.make_current

    @account.reputation = 1
    @account.save
    set_key(plan_key(@account.subscription.subscription_plan_id), 200, nil)
    Bullet.add_whitelist type: :unused_eager_loading, class_name: 'ForumCategory', association: :forums
    Bullet.add_whitelist type: :n_plus_one_query, class_name: 'ForumCategory', association: :account
    # To prevent DynamoDB errors.
    SpamCounter.stubs(:count).returns(0)
    Rails.logger.debug "START #{@test_name}"
  end

  def account_wrap(user = nil)
    yield
  ensure
    @account.make_current
    (user || @agent).make_current
  end

  def teardown
    reconsider_gc_deferment
    super
    Account.reset_current_account
    User.reset_current_user
    reset_request_headers
    clear_instance_variables
    Rails.logger.debug "END #{@test_name}"
  end
end
