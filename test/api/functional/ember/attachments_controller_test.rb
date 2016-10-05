require_relative '../../test_helper'
class Ember::AttachmentsControllerTest < ActionController::TestCase
  include AttachmentsTestHelper

  def wrap_cname(params)
    { attachment: params }
  end

  def setup
    super
    before_all
  end

  def before_all
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
  end

  def attachment_params_hash
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    params_hash = { user_id: @agent.id, content: file }
  end

  def test_create_with_no_params
    post :create, construct_params({version: 'private'}, {})
    match_json([bad_request_error_pattern('content', :missing_field)])
    assert_response 400
  end

  def test_create_with_invalid_params
    post :create, construct_params({version: 'private'}, {user_id: 'ABC', content: 'XYZ'})
    match_json([bad_request_error_pattern('user_id', :datatype_mismatch, expected_data_type: 'Positive Integer'),
                bad_request_error_pattern('content', :datatype_mismatch, expected_data_type: 'valid file format', prepend_msg: :input_received, given_data_type: String)])
    assert_response 400
  end

  def test_create_with_invalid_user_id
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :create, construct_params({version: 'private'}, attachment_params_hash.merge(user_id: 1000))
    DataTypeValidator.any_instance.unstub(:valid_type?)
    match_json([bad_request_error_pattern('user_id', :absent_in_db, resource: :contact, attribute: :user_id)])
    assert_response 400
  end

  def test_create_with_errors
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    Helpdesk::Attachment.any_instance.stubs(:save).returns(false)
    post :create, construct_params({version: 'private'}, attachment_params_hash)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    Helpdesk::Attachment.any_instance.unstub(:save)
    assert_response 500
  end

  def test_create_without_user_id
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :create, construct_params({version: 'private'}, attachment_params_hash.except(:user_id))
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 200
    latest_attachment = Helpdesk::Attachment.last
    match_json(attachment_pattern({}, latest_attachment))
    assert_equal latest_attachment.attachable_type, 'UserDraft'
  end

  def test_create_with_user_id
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :create, construct_params({version: 'private'}, attachment_params_hash)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 200
    latest_attachment = Helpdesk::Attachment.last
    match_json(attachment_pattern({}, latest_attachment))
    assert_equal latest_attachment.attachable_type, 'UserDraft'
    assert_equal latest_attachment.attachable_id, @agent.id
  end
end
