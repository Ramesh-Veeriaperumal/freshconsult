require_relative 'simple_cov_setup'
require File.expand_path('../../../../config/environment', __FILE__)

require 'rails/test_help'
require 'minitest/rails'
require 'authlogic/test_case'
require 'minitest/pride'
require 'minitest/reporters'
require 'json_expressions/minitest'
include ActiveSupport::Rescuable

Dir["#{Rails.root}/test/api/helpers/*.rb"].each { |file| require file }
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
include GroupHelper
include NoteHelper
include ProductsHelper
include EmailConfigsHelper
include BusinessCalendarsHelper
