require_relative '../unit_test_helper.rb'
['account_helper.rb', 'controller_helper.rb', 'user_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
Dir["#{Rails.root}/test/api/helpers/*.rb"].each { |file| require file }
require 'authlogic/test_case'
include AccountHelper
include ControllerHelper
include UsersHelper
