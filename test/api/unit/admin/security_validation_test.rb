# frozen_string_literal: true

require_relative '../../../../test/api/unit_test_helper'
require Rails.root.join('test', 'api', 'helpers', 'admin', 'security_test_helper.rb')

class Admin::SecurityValidationTest < ActionView::TestCase
  include Admin::SecurityTestHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    Admin::SecurityValidation.any_instance.stubs(:sso_configuration_error).returns([])
  end

  def teardown
    Account.unstub(:current)
    Admin::SecurityValidation.any_instance.unstub(:sso_configuration_error)
  end

  VALID_SECURITY_SETTINGS.each_with_index do |params, index|
    define_method "test_valid_security_param_#{index}" do
      validation = security_validation_class.new(params)
      assert validation.valid?
    end
  end

  INVALID_SECURITY_SETTINGS.each_with_index do |params, index|
    define_method "test_invalid_security_param_#{index}" do
      validation = security_validation_class.new(params)
      assert validation.invalid?
    end
  end

  def security_validation_class
    'Admin::SecurityValidation'.constantize
  end
end
