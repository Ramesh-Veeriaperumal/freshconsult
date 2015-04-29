ENV["RAILS_ENV"] = "test"

require 'simplecov'
require 'simplecov-csv'
require 'simplecov-rcov'

SimpleCov.start do
  add_filter  SimpleCov::StringFilter.new('^((?!api\/).)*$')

  
  add_group 'api', 'api/'
  add_group 'apiconcerns', 'api/app/controllers/concerns'
  add_group 'apivalidations', 'api/app/controllers/validations'
  add_group 'apicontrollers', 'api/app/controllers'
  add_group 'apilib', 'api/lib'
end

SimpleCov.coverage_dir 'tmp/coverage'

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::CSVFormatter,
  SimpleCov::Formatter::RcovFormatter,
]


require File.expand_path("../../config/environment", __FILE__)

require "rails/test_help"
require "minitest/rails"
require 'authlogic/test_case'
require "minitest/pride"
require "minitest/reporters"

Dir["#{Rails.root}/spec/support/*.rb"].each {|file| require file}
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

Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new, Minitest::Reporters::JUnitReporter.new]
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
    create_test_account
    @account = Account.first
    @agent = get_admin
    auth = ActionController::HttpAuthentication::Basic.encode_credentials(@agent.single_access_token, "X")
    @headers = {"HTTP_AUTHORIZATION"=>auth, "HTTP_HOST" => "localhost.freshpo.com"}
  end

  self.use_transactional_fixtures = false
  fixtures :all
end
