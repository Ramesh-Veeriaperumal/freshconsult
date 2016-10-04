require_relative '../../test_helper'
class Ember::ContactsControllerTest < ActionController::TestCase
  include UsersTestHelper

  def wrap_cname(params)
    { contact: params }
  end

  def test_bulk_delete_with_no_params
    put :bulk_delete, construct_params({ version: 'private' }, {})
    assert_response 400
    match_json([bad_request_error_pattern('ids', :missing_field)])
  end

  def test_bulk_delete_with_invalid_ids
    contact_ids = []
    rand(2..10).times do
      contact_ids << add_new_user(@account).id
    end
    invalid_ids = [1000, 2000]
    ids_to_delete = [*contact_ids, *invalid_ids]
    put :bulk_delete, construct_params({ version: 'private' }, {ids: ids_to_delete})
    failures = {}
    invalid_ids.each { |id| failures[id] = { :id => :"is invalid" } }
    match_json(partial_success_response_pattern(contact_ids, failures))
    assert_response 202
  end

  def test_bulk_delete_with_errors_in_deletion
    contacts = []
    rand(2..10).times do
      contacts << add_new_user(@account)
    end
    ids_to_delete = contacts.map(&:id)
    User.any_instance.stubs(:save).returns(false)
    put :bulk_delete, construct_params({ version: 'private' }, {ids: ids_to_delete})
    failures = {}
    ids_to_delete.each { |id| failures[id] = { :id => :unable_to_perform } }
    match_json(partial_success_response_pattern([], failures))
    assert_response 202
  end

  def test_bulk_delete_with_valid_ids
    contact_ids = []
    rand(2..10).times do
      contact_ids << add_new_user(@account).id
    end
    put :bulk_delete, construct_params({ version: 'private' }, {ids: contact_ids})
    assert_response 204
  end


  # Whitelist user
  def test_whitelist_contact
    sample_user = create_blocked_contact(@account)
    put :whitelist, construct_params({ version: 'private' }, false).merge({ id: sample_user.id })
    assert_response 204
    confirm_user_whitelisting([sample_user.id])
  end

  def test_whitelist_an_invalid_contact
    put :whitelist, construct_params({ version: 'private' }, false).merge({ id: 0 })
    assert_response 404
  end

  def test_whitelist_an_unblocked_contact
    sample_user = add_new_user(@account)
    put :whitelist, construct_params({ version: 'private' }, false).merge({ id: sample_user.id })
    assert_response 400
    match_json([bad_request_error_pattern(:blocked, 'is false. You can whitelist only blocked users.')])
  end

  #bulk whitelist users
  def test_bulk_whitelist_with_no_params
    put :bulk_whitelist, construct_params({ version: 'private' }, {})
    assert_response 400
    match_json([bad_request_error_pattern('ids', :missing_field)])
  end

  def test_bulk_whitelist_with_invalid_ids
    contact_ids = []
    rand(2..10).times do
      contact_ids << create_blocked_contact(@account).id
    end
    last_id = contact_ids.max
    invalid_ids = [last_id + 50, last_id + 100]
    ids_to_whitelist = [*contact_ids, *invalid_ids]
    put :bulk_whitelist, construct_params({ version: 'private' }, { ids: ids_to_whitelist })
    failures = {}
    invalid_ids.each { |id| failures[id] = { :id => :"is invalid" } }
    match_json(partial_success_response_pattern(contact_ids, failures))
    assert_response 202
    confirm_user_whitelisting(contact_ids)
  end

  def test_bulk_whitelist_with_errors_in_whitelisting
    contacts = []
    rand(2..10).times do
      contacts << create_blocked_contact(@account)
    end
    ids_to_whitelist = contacts.map(&:id)
    User.any_instance.stubs(:save).returns(false)
    put :bulk_whitelist, construct_params({ version: 'private' }, { ids: ids_to_whitelist })
    failures = {}
    ids_to_whitelist.each { |id| failures[id] = { :id => :unable_to_perform } }
    match_json(partial_success_response_pattern([], failures))
    assert_response 202
  end

  def test_bulk_whitelist_with_valid_ids
    contact_ids = []
    rand(2..10).times do
      contact_ids << create_blocked_contact(@account).id
    end
    put :bulk_whitelist, construct_params({ version: 'private' }, { ids: contact_ids })
    assert_response 204
    confirm_user_whitelisting(contact_ids)
  end

end
