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
    errors = {}
    invalid_ids.each { |id| errors[id] = :"is invalid" }
    match_json(partial_success_response_pattern(contact_ids, errors))
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
    errors = {}
    ids_to_delete.each { |id| errors[id] = :unable_to_delete }
    match_json(partial_success_response_pattern([], errors))
    assert_response 202
  end

  def test_bulk_delete_with_valid_ids
    contact_ids = []
    rand(2..10).times do
      contact_ids << add_new_user(@account).id
    end
    put :bulk_delete, construct_params({ version: 'private' }, {ids: contact_ids})
    assert_response 205
  end

end
