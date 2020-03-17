ENV['RAILS_ENV'] = 'test'

require File.expand_path('../../../../config/environment', __FILE__)
require "minitest/rails"
require 'rails/test_help'
# require 'authlogic/test_case'
# require 'sidekiq/testing'
require 'minitest/reporters'
require 'json_expressions/minitest'
require 'minitest/spec'

['test_suite_methods.rb'].each { |file| require Rails.root.join("test/lib/helpers/#{file}") }
['users_test_helper.rb'].each { |file| require Rails.root.join("test/models/helpers/#{file}") }
['test_class_methods.rb'].each { |file| require Rails.root.join("test/api/helpers/#{file}") }
['account_test_helper.rb', 'controller_test_helper.rb'].each { |file| require Rails.root.join("test/core/helpers/#{file}") }

# Dir["#{Rails.root}/test/models/helpers/.rb"].each { |file| require file }
# Dir["#{Rails.root}/test/core/helpers/account_test_helper.rb"].each { |file| require file }
# Dir["#{Rails.root}/test/core/helpers/controller_test_helper.rb"].each { |file| require file }

include AccountTestHelper
include ModelsUsersTestHelper
include ControllerTestHelper
include ActiveSupport::Rescuable

Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new, Minitest::Reporters::JUnitReporter.new(ENV.fetch('MINITEST_REPORT_DIR', 'test/reports'))]
