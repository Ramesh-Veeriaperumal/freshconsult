require_relative '../../test_helper'
module Ember
  class ContactsControllerTest < ActionController::TestCase
    include UsersTestHelper
    include AttachmentsTestHelper

    def wrap_cname(params)
      { contact: params }
    end

    def contact_params_hash
      params_hash = {
        name: Faker::Lorem.characters(15),
        email: Faker::Internet.email
      }
    end

    def test_create_with_incorrect_avatar_type
      params_hash = contact_params_hash.merge({avatar_id: 'ABC'})
      post :create, construct_params({version: 'private'}, params_hash)
      match_json([bad_request_error_pattern(:avatar_id, :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: String)])
      assert_response 400
    end

    def test_create_with_avatar_and_avatar_id
      attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      file = fixture_file_upload('/files/image33kb.jpg', 'image/jpg')
      params_hash = contact_params_hash.merge({avatar_id: attachment_id, avatar: file})
      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      @request.env['CONTENT_TYPE'] = 'multipart/form-data' 
      post :create, construct_params({version: 'private'}, params_hash)
      DataTypeValidator.any_instance.unstub(:valid_type?)
      match_json([bad_request_error_pattern(:avatar_id, :only_avatar_or_avatar_id)])
      assert_response 400
    end

    def test_create_with_invalid_avatar_id
      attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      invalid_id = attachment_id + 10
      params_hash = contact_params_hash.merge({avatar_id: invalid_id})
      post :create, construct_params({version: 'private'}, params_hash)
      match_json([bad_request_error_pattern(:avatar_id, :invalid_list, list: invalid_id.to_s)])
      assert_response 400
    end

    def test_create_with_invalid_avatar_size
      attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      params_hash = contact_params_hash.merge({avatar_id: attachment_id})
      Helpdesk::Attachment.any_instance.stubs(:content_file_size).returns(20_000_000)
      post :create, construct_params({version: 'private'}, params_hash)
      Helpdesk::Attachment.any_instance.unstub(:content_file_size)
      match_json([bad_request_error_pattern(:avatar_id, :invalid_size, max_size: '5 MB', current_size: '19.1 MB')])
      assert_response 400
    end

    def test_create_with_invalid_avatar_extension
      attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      params_hash = contact_params_hash.merge({avatar_id: attachment_id})
      post :create, construct_params({version: 'private'}, params_hash)
      match_json([bad_request_error_pattern(:avatar_id, :upload_jpg_or_png_file, current_extension: '.txt')])
      assert_response 400
    end

    def test_create_with_errors
      file = fixture_file_upload('/files/image33kb.jpg', 'image/jpg')
      avatar_id = create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: @agent.id).id
      params_hash = contact_params_hash.merge({avatar_id: avatar_id})
      User.any_instance.stubs(:save).returns(false)
      post :create, construct_params({version: 'private'}, params_hash)
      User.any_instance.unstub(:save)
      assert_response 500
    end

    def test_create_with_avatar_id
      file = fixture_file_upload('/files/image33kb.jpg', 'image/jpg')
      avatar_id = create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: @agent.id).id
      params_hash = contact_params_hash.merge({avatar_id: avatar_id})
      post :create, construct_params({version: 'private'}, params_hash)
      assert_response 201
      match_json(deleted_contact_pattern(params_hash, User.last))
      match_json(deleted_contact_pattern({}, User.last))
      assert User.last.avatar.id == avatar_id
    end

    def test_deletion
      contact_id = add_new_user(@account).id
      delete :destroy, controller_params({version: 'private', id: contact_id})
      assert_response 204
    end

    def test_deletion_of_non_existing_contact
      contact_id = add_new_user(@account).id + 10
      delete :destroy, controller_params({version: 'private', id: contact_id})
      assert_response 404
    end

    def test_deletion_of_deleted_contact
      contact = add_new_user(@account, deleted: true)
      delete :destroy, controller_params({version: 'private', id: contact.id})
      assert_response 405
    end

    def test_deletion_with_errors
      contact = add_new_user(@account)
      User.any_instance.stubs(:save).returns(false)
      User.any_instance.stubs(:errors).returns(:name => 'cannot be nil')
      delete :destroy, controller_params({version: 'private', id: contact.id})
      User.any_instance.unstub(:save)
      User.any_instance.unstub(:errors)
      assert_response 400
    end

    def test_restore
      contact = add_new_user(@account, {deleted: true})
      put :restore, controller_params({version: 'private', id: contact.id})
      assert_response 204
    end

    def test_restoring_non_existing_contact
      contact_id = add_new_user(@account).id + 10
      put :restore, controller_params({version: 'private', id: contact_id})
      assert_response 404
    end

    def test_restoring_active_contact
      contact_id = add_new_user(@account).id
      put :restore, controller_params({version: 'private', id: contact_id})
      assert_response 404
    end

    def test_send_invite
      contact = add_new_user(@account, active: false)
      put :send_invite, controller_params({version: 'private', id: contact.id})
      assert_response 204
    end

    def test_send_invite_to_active_contact
      contact = add_new_user(@account)
      put :send_invite, controller_params({version: 'private', id: contact.id})
      match_json([bad_request_error_pattern('id', :unable_to_perform)])
      assert_response 400
    end

    def test_send_invite_to_deleted_contact
      contact = add_new_user(@account, deleted: true, active: false)
      put :send_invite, controller_params({version: 'private', id: contact.id})
      match_json([bad_request_error_pattern('id', :unable_to_perform)])
      assert_response 400
    end

    def test_index_with_tags
      tags = [Faker::Lorem.word, Faker::Lorem.word]
      contact_ids = []
      rand(2..10).times do
        contact_ids << add_new_user(@account, tags: tags.join(', ')).id
      end
      get :index, controller_params({version: 'private' , tag: tags[0]})
      assert_response 200
      assert response.api_meta[:count] == contact_ids.size
    end

    def test_index_with_invalid_tags
      contact_ids = []
      rand(2..10).times do
        contact_ids << add_new_user(@account).id
      end
      get :index, controller_params({version: 'private', tag: Faker::Lorem.word})
      assert_response 200
      assert response.api_meta[:count] == 0
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
      invalid_ids = [contact_ids.last + 20, contact_ids.last + 30]
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

    def bulk_restore
      contact_ids = []
      rand(2..10).times do
        contact_ids << add_new_user(@account, deleted: true).id
      end
      put :bulk_restore, construct_params({ version: 'private' }, {ids: contact_ids})
      assert_response 204
    end

    def test_bulk_restore_of_active_contacts
      contact_ids = []
      rand(2..10).times do
        contact_ids << add_new_user(@account).id
      end
      put :bulk_restore, construct_params({ version: 'private' }, {ids: contact_ids})
      failures = {}
      contact_ids.each { |id| failures[id] = { :id => :unable_to_perform } }
      match_json(partial_success_response_pattern([], failures))
      assert_response 202
    end

    def test_bulk_send_invite
      contact_ids = []
      rand(2..10).times do
        contact_ids << add_new_user(@account, active: false).id
      end
      put :bulk_send_invite, construct_params({ version: 'private' }, {ids: contact_ids})
      assert_response 204
    end

    def test_bulk_send_invite_to_deleted_contacts
      contact_ids = []
      rand(2..10).times do
        contact_ids << add_new_user(@account, active: false, deleted: true).id
      end
      valid_contact = add_new_user(@account, active: false)
      put :bulk_send_invite, construct_params({ version: 'private' }, {ids: [*contact_ids, valid_contact.id]})
      failures = {}
      contact_ids.each { |id| failures[id] = { :id => :unable_to_perform } }
      match_json(partial_success_response_pattern([valid_contact.id], failures))
      assert_response 202
    end
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
