require_relative '../unit_test_helper.rb'
Dir["#{Rails.root}/spec/support/*.rb"].each { |file| require file }
Dir["#{Rails.root}/test/api/helpers/*.rb"].each { |file| require file }
require 'authlogic/test_case'
include AccountHelper
include ControllerHelper
include UsersHelper
