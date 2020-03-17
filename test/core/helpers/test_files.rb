ENV['RAILS_ENV'] = 'test'

require File.expand_path('../../../../config/environment', __FILE__)
require "minitest/rails"
require 'rails/test_help'
require 'authlogic/test_case'
require 'sidekiq/testing'
require 'minitest/reporters'

Dir["#{Rails.root}/test/core/helpers/*.rb"].each { |file| require file }
Dir["#{Rails.root}/test/core/custom_assertions/*.rb"].each { |file| require file }

include AccountTestHelper
include ControllerTestHelper
include CoreUsersTestHelper
include ActiveSupport::Rescuable

Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new, Minitest::Reporters::JUnitReporter.new(ENV.fetch('MINITEST_REPORT_DIR', 'test/reports'))]
