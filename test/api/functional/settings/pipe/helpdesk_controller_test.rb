require_relative '../../../test_helper'

module Settings
  class Pipe::HelpdeskControllerTest < ActionController::TestCase
    def wrap_cname(params)
      { api_helpdesk: params }
    end
    
    def test_toggle_email_valid_enable
      Account.current.rollback(:disable_emails)
      put :toggle_email, construct_params({ version: 'private', disabled: true})
      assert Account.current.launched?(:disable_emails)
      Account.current.rollback(:disable_emails)
    end  

    def test_toggle_email_valid_disable
      Account.current.launch(:disable_emails)
      put :toggle_email, construct_params({ version: 'private', disabled: false})
      assert !Account.current.launched?(:disable_emails)
    end

    def test_toggle_email_invalid_enable
      put :toggle_email, construct_params({ version: 'private', disabledX: true})
      assert_response 400
      put :toggle_email, construct_params({ version: 'private', disabled: "true"})
      assert_response 400
      put :toggle_email, construct_params({ version: 'private', disabledX: 123})
      assert_response 400
    end
  end
end