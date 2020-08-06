require_relative 'helpers/test_files.rb'
require 'fakeweb'

class ActionController::TestCase
  rescue_from Aws::DynamoDB::Errors::ResourceNotFoundException do |exception|
    Rake::Task['forum_moderation:create_tables'].invoke(Time.zone.now.year, Time.zone.now.month) if  Rails.env.test?
    Rake::Task['forum_moderation:create_tables'].invoke(Time.zone.now.year, (Time.zone.now.month + 1)) if  Rails.env.test?
  end

  def setup
    activate_authlogic
    create_test_account
    set_request_params
    SpamCounter.stubs(:count).returns(0)
  end

  self.use_transactional_fixtures = false
  fixtures :all
end

class ActiveSupport::TestCase
  def setup
    create_test_account
  end

  self.use_transactional_fixtures = false
  fixtures :all 
end