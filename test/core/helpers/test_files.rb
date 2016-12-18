ENV['RAILS_ENV'] = 'test'

require File.expand_path('../../../../config/environment', __FILE__)
require "minitest/rails"
require 'rails/test_help'
require 'authlogic/test_case'
require 'sidekiq/testing'

Dir["#{Rails.root}/test/core/helpers/*.rb"].each { |file| require file }
Dir["#{Rails.root}/test/core/custom_assertions/*.rb"].each { |file| require file }

include AccountTestHelper
include ControllerTestHelper
include UsersTestHelper
include ActiveSupport::Rescuable