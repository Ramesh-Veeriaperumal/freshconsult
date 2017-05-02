require_relative '../../unit_test_helper'

module Pipe
  class HelpdeskValidationTest < ActionView::TestCase
  	
  	def test_valid
  		Account.stubs(:current).returns(Account.first)
  		controller_params = { disabled: true }
  		item = nil
  		helpdesk = HelpdeskValidation.new(controller_params, item)
  		assert helpdesk.valid?(:toggle_email)
  		Account.unstub(:current)
  	end

  	def test_invalid
  		Account.stubs(:current).returns(Account.first)
  		controller_params = { disabled: 1 }
  		item = nil
  		helpdesk = HelpdeskValidation.new(controller_params, item)
  		assert !helpdesk.valid?(:toggle_email)
  		Account.unstub(:current)
  	end

  end
end  	