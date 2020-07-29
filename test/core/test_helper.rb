require_relative 'helpers/test_files.rb'
require 'fakeweb'

class ActionController::TestCase
  rescue_from AWS::DynamoDB::Errors::ResourceNotFoundException do |exception|
    Rake::Task['forum_moderation:create_tables'].invoke(Time.zone.now.year, Time.zone.now.month) if  Rails.env.test?
    Rake::Task['forum_moderation:create_tables'].invoke(Time.zone.now.year, (Time.zone.now.month + 1)) if  Rails.env.test?
  end

  def setup
    activate_authlogic
    # To Prevent agent central publish error
    Agent.any_instance.stubs(:user_uuid).returns('123456789')
    create_test_account
    set_request_params
    SpamCounter.stubs(:count).returns(0)
  end

  self.use_transactional_fixtures = false
  fixtures :all
end

class ActiveSupport::TestCase
  def setup
    # To Prevent agent central publish error
    Agent.any_instance.stubs(:user_uuid).returns('123456789')
    create_test_account
  end

  self.use_transactional_fixtures = false
  fixtures :all 
end