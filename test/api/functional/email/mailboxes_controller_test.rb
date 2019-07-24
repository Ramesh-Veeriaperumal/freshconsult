require_relative '../../test_helper'
class Email::MailboxesControllerTest < ActionController::TestCase
  include EmailConfigsTestHelper
  def test_delete_secondary_email
    email_config = create_email_config(active: 'false', primary_role: 'false')
    delete :destroy, controller_params(version: 'private', id: email_config.id)
    assert_response 204
  end

  def test_cannot_delete_primary_email
    email_config = create_email_config(active: 'true')
    delete :destroy, controller_params(version: 'private', id: email_config.id)
    assert_response 400
    match_json([bad_request_error_pattern('error', :cannot_delete_primary_email)])
  end

  def test_invalid_id
    delete :destroy, controller_params(version: 'private', id: Faker::Number.number(5))
    assert_response 404
  end
end
