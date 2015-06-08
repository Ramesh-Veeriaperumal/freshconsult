require_relative 'simple_cov_setup'
require File.expand_path('../../../config/environment', __FILE__)

require 'rails/test_help'
require 'minitest/rails'
require 'authlogic/test_case'
require 'minitest/pride'
require 'minitest/reporters'
require 'json_expressions/minitest'

Dir["#{Rails.root}/test/helpers/*.rb"].each { |file| require file }
Dir["#{Rails.root}/spec/support/*.rb"].each { |file| require file }
include AccountHelper
include UsersHelper
include ControllerHelper
include Authlogic::TestCase
include APIAuthHelper
include ForumHelper
include CompanyHelper
include UsersHelper
include TicketHelper
