ENV["RAILS_ENV"] = "test"
require File.expand_path("../../config/environment", __FILE__)
require "rails/test_help"
require "minitest/rails"
require 'authlogic/test_case'
require "minitest/pride"

Dir["/Users/user/git/helpkit/spec/support/*.rb"].each {|file| require file}
include AccountHelper
include UsersHelper
include ControllerHelper
include Authlogic::TestCase
include APIAuthHelper

ES_ENABLED = false
GNIP_ENABLED = false
RIAK_ENABLED = false

DatabaseCleaner.clean_with(:truncation,
                                 {:pre_count => true, :reset_ids => false})
$redis_others.flushall

class ActiveSupport::TestCase

  def setup
    activate_authlogic
    create_test_account
    @account = Account.first
    @account.make_current
    @agent = get_admin
    @request.host = @account.full_domain
    @request.env['HTTP_REFERER'] = '/sessions/new'
    @request.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36\
                                  (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36"
  end

  self.use_transactional_fixtures = false
  fixtures :all
end

class ActionDispatch::IntegrationTest

  def setup
    @account = Account.first
    @agent = get_admin
    auth = ActionController::HttpAuthentication::Basic.encode_credentials(@agent.single_access_token, "X")
    @headers = {"HTTP_AUTHORIZATION"=>auth, "HTTP_HOST" => "localhost.freshpo.com"}
  end

  self.use_transactional_fixtures = false
  fixtures :all
end
