ENV['RAILS_ENV'] = 'test'
require File.expand_path('../../../config/environment', __FILE__)
require 'minitest/spec'

Dir["#{Rails.root}/spec/support/*.rb"].each { |file| require file }
Dir["#{Rails.root}/test/api/helpers/*.rb"].each { |file| require file }
Dir["#{Rails.root}/test/search/helpers/*.rb"].each { |file| require file }

include ActiveSupport::Rescuable
include AccountHelper
include UsersHelper
include CompanyHelper
include ForumHelper
include SolutionsHelper
include TicketHelper
include NoteHelper
include Helpers::TicketFieldsTestHelper
include ContactFieldsHelper
include Searchv2::SearchHelper

class ActionController::TestCase
  def setup
    activate_authlogic
    get_agent
    @account.make_current
    create_session

    @request.host = @account.full_domain
    @request.env['CONTENT_TYPE'] = 'application/json'
    @request.env["HTTP_ACCEPT"] = 'application/json'

    setup_searchv2
  end

  def self.fixture_path(path = File.join(Rails.root, 'test/search/fixtures/'))
    path
  end

  def teardown
    teardown_searchv2
    super
  end

  def parse_response(response)
    JSON.parse(response)
  end

  def parsed_attr(response, attribute)
    parse_response(response)['results'].map { |item| item[attribute] }
  end

  def parsed_support_attr(response, attribute)
    parse_response(response).map { |item| item[attribute] }
  end

  def log_in(user)
    refute_nil user
    session = UserSession.create!(user)
    session.save!
  end

  def log_out
    UserSession.find.try(:destroy)
  end

  ActiveRecord::Base.logger.level = 1
  self.use_transactional_fixtures = false
  fixtures :all
end