ENV['RAILS_ENV'] = 'test'

require File.expand_path('../../../../config/environment', __FILE__)
require "minitest/rails"
require 'rails/test_help'
require 'authlogic/test_case'
require 'sidekiq/testing'
require 'minitest/reporters'
require 'json_expressions/minitest'

Dir["#{Rails.root}/test/models/helpers/*.rb"].each { |file| require file }
Dir["#{Rails.root}/test/core/helpers/account_test_helper.rb"].each { |file| require file }
Dir["#{Rails.root}/test/core/helpers/controller_test_helper.rb"].each { |file| require file }

include AccountTestHelper
include UsersTestHelper
include ControllerTestHelper
include ActiveSupport::Rescuable

Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new]