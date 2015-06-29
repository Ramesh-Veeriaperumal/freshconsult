ENV['RAILS_ENV'] = 'test'

require_relative 'helpers/test_files.rb'

class ActionController::TestCase

  rescue_from AWS::DynamoDB::Errors::ResourceNotFoundException do |exception|
    Rake::Task["forum_moderation:create_tables"].invoke(Time.zone.now.year,Time.zone.now.month) if  Rails.env.test?
    Rake::Task["forum_moderation:create_tables"].invoke(Time.zone.now.year,(Time.zone.now.month+1)) if  Rails.env.test?
  end

  def setup
    activate_authlogic
    get_agent
    @account.make_current
    create_session
    set_request_params
  end

  self.use_transactional_fixtures = false
  fixtures :all
end

class ActionDispatch::IntegrationTest

  rescue_from AWS::DynamoDB::Errors::ResourceNotFoundException do |exception|
    Rake::Task["forum_moderation:create_tables"].invoke(Time.zone.now.year,Time.zone.now.month) if  Rails.env.test?
    Rake::Task["forum_moderation:create_tables"].invoke(Time.zone.now.year,(Time.zone.now.month+1)) if  Rails.env.test?
  end

  def setup
    get_agent
    set_request_headers
  end

  self.use_transactional_fixtures = false
  fixtures :all
end
