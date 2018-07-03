require_relative '../../test_helper'
class Contacts::MiscControllerTest < ActionController::TestCase
  include UsersTestHelper
  include CustomFieldsTestHelper
  BULK_CONTACT_CREATE_COUNT = 2
  def setup
    super
    initial_setup
  end

  @@initial_setup_run = false

  def initial_setup
    return if @@initial_setup_run
    @account.add_feature(:falcon)
    @account.reload
    @@initial_setup_run = true
  end

  def test_send_invite
    contact = add_new_user(@account, active: false)
    put :send_invite, controller_params(id: contact.id)
    assert_response 204
  end

  def test_send_invite_to_active_contact
    contact = add_new_user(@account, active: true)
    put :send_invite, controller_params(id: contact.id)
    match_json([bad_request_error_pattern('id', :invalid_user_for_activation, reason: "active")])
    assert_response 400
  end

  def test_send_invite_to_deleted_contact
    contact = add_new_user(@account, deleted: true, active: false)
    put :send_invite, controller_params( id: contact.id)
    match_json([bad_request_error_pattern('id', :invalid_user_for_activation, reason: "deleted")])
    assert_response 400
  end

  def test_send_invite_to_merged_contact
    contact = add_new_user(@account, deleted: true)
    contact.parent_id = 999
    contact.save
    put :send_invite, controller_params( id: contact.id)
    match_json([bad_request_error_pattern('id', :invalid_user_for_activation, reason: "merged")])
    assert_response 400
    contact.parent_id = nil
  end

  def test_send_invite_to_blocked_contact
    contact = add_new_user(@account, blocked: true)
    put :send_invite, controller_params( id: contact.id)
    match_json([bad_request_error_pattern('id', :invalid_user_for_activation, reason: "blocked")])
    assert_response 400
  end

end
