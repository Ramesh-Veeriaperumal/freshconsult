require_relative 'helpers/test_files.rb'
class ActionController::TestCase
  rescue_from AWS::DynamoDB::Errors::ResourceNotFoundException do |exception|
    Rake::Task['forum_moderation:create_tables'].invoke(Time.zone.now.year, Time.zone.now.month) if  Rails.env.test?
    Rake::Task['forum_moderation:create_tables'].invoke(Time.zone.now.year, (Time.zone.now.month + 1)) if  Rails.env.test?
  end

  def setup
    activate_authlogic
    get_agent
    @account.make_current
    create_session
    set_request_params
    set_key(account_key, 1000, nil)
    set_key(default_key, 100, nil)
    # To prevent DynamoDB errors.
    SpamCounter.stubs(:count).returns(0)
  end

  def self.fixture_path(path = File.join(Rails.root, 'test/api/fixtures/'))
    path
  end

  def teardown
    @controller.instance_variables.each do |ivar|
      @controller.instance_variable_set(ivar, nil)
    end
    super
  end
  ActiveRecord::Base.logger.level = 1
  self.use_transactional_fixtures = false
  fixtures :all
end

class ActionDispatch::IntegrationTest
  rescue_from AWS::DynamoDB::Errors::ResourceNotFoundException do |exception|
    Rake::Task['forum_moderation:create_tables'].invoke(Time.zone.now.year, Time.zone.now.month) if  Rails.env.test?
    Rake::Task['forum_moderation:create_tables'].invoke(Time.zone.now.year, (Time.zone.now.month + 1)) if  Rails.env.test?
  end

  # For logging query details in a separate folder
  FileUtils.mkdir_p "#{Rails.root}/test/api/query_reports"

  def setup
    get_agent
    set_request_headers
    host!('localhost.freshpo.com')
    set_key(account_key, 500, nil)
    set_key(default_key, 400, nil)
    set_key(plan_key(@account.subscription.subscription_plan_id), 200, nil)
    Bullet.add_whitelist type: :unused_eager_loading, class_name: 'ForumCategory', association: :forums
    Bullet.add_whitelist type: :n_plus_one_query, class_name: 'ForumCategory', association: :account
    # To prevent DynamoDB errors.
    SpamCounter.stubs(:count).returns(0)
  end

  ActiveRecord::Base.logger.level = 1
  self.use_transactional_fixtures = false
  fixtures :all
end
