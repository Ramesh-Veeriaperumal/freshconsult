require_relative '../../test_helper'
['ticket_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
class Ember::AttachmentsControllerTest < ActionController::TestCase
  include AttachmentsTestHelper
  include TicketHelper

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

  def attachment_params_hash_key_file
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    params_hash = { user_id: @agent.id, file: file }
  end

  def attachment_unicode_params_hash
    file = fixture_file_upload('files/shib%E2%80%AE3pm.txt', 'plain/text', :binary)
    params_hash = { user_id: @agent.id, content: file }
  end

  def inline_attachment_params_hash
    file = fixture_file_upload('files/image33kb.jpg', 'image/jpeg')
    params_hash = { content: file, inline: true, inline_type: 1 }
  end

  def jpeg_attachment_params_hash
    file = fixture_file_upload('files/image33kb.jpg', 'image/jpeg')
    params_hash = { content: file }
  end

  def image_with_exif_attachment_params_hash
    file = fixture_file_upload('files/image_with_exif.jpg', 'image/jpeg')
    params_hash = { content: file }
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
    match_json(attachment_pattern(latest_attachment))
    assert_equal latest_attachment.attachable_type, 'UserDraft'
  end

  def test_create_with_user_id
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :create, construct_params({version: 'private'}, attachment_params_hash)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 200
    latest_attachment = Helpdesk::Attachment.last
    match_json(attachment_pattern(latest_attachment))
    assert_equal latest_attachment.attachable_type, 'UserDraft'
    assert_equal latest_attachment.attachable_id, @agent.id
  end

  def test_create_with_file_key_without_user_id
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :create, construct_params({ version: 'private' }.merge(attachment_params_hash_key_file.except(:user_id)), attachment_params_hash_key_file.except(:user_id))
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 200
    latest_attachment = Helpdesk::Attachment.last
    match_json(attachment_pattern(latest_attachment))
    assert_equal latest_attachment.attachable_type, 'UserDraft'
  end

  def test_create_with_file_key_with_user_id
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :create, construct_params({ version: 'private' }.merge(attachment_params_hash_key_file.except(:user_id)), attachment_params_hash_key_file)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 200
    latest_attachment = Helpdesk::Attachment.last
    match_json(attachment_pattern(latest_attachment))
    assert_equal latest_attachment.attachable_type, 'UserDraft'
    assert_equal latest_attachment.attachable_id, @agent.id
  end

  def test_create_inline_image_with_invalid_type
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :create, construct_params({version: 'private'}, inline_attachment_params_hash.merge(inline_type: 100))
    assert_response 400
    match_json([bad_request_error_pattern(:inline_type, :not_included, list: '1,2,3,4,5')])
    DataTypeValidator.any_instance.unstub(:valid_type?)
  end

  def test_create_inline_image_with_invalid_file_extension
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    post :create, construct_params({version: 'private'}, inline_attachment_params_hash.merge(content: file))
    assert_response 400
    match_json([bad_request_error_pattern(:content, :invalid_image_file, current_extension: '.txt')])
    DataTypeValidator.any_instance.unstub(:valid_type?)
  end

  def test_create_inline_image_with_invalid_image
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    Helpdesk::Attachment.any_instance.stubs(:valid_image?).returns(false)
    post :create, construct_params({version: 'private'}, inline_attachment_params_hash)
    assert_response 400
    match_json([bad_request_error_pattern(:content, :incorrect_image_dimensions)])
    DataTypeValidator.any_instance.unstub(:valid_type?)
  end

  def test_create_inline_image
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    Helpdesk::Attachment.any_instance.stubs(:valid_image?).returns(true)
    post :create, construct_params({version: 'private'}, inline_attachment_params_hash)
    assert_response 200
    latest_attachment = Helpdesk::Attachment.last
    match_json(attachment_pattern(latest_attachment))
    assert_equal latest_attachment.attachable_type, 'Tickets Image Upload'
    assert latest_attachment.inline_url.present?
    Helpdesk::Attachment.any_instance.unstub(:valid_image?)
    DataTypeValidator.any_instance.unstub(:valid_type?)
  end

  def test_create_jpeg_image
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    Helpdesk::Attachment.any_instance.stubs(:valid_image?).returns(true)
    post :create, construct_params({version: 'private'}, jpeg_attachment_params_hash)
    assert_response 200
    thumb_url = JSON.parse(response.body)['thumb_url']
    AwsWrapper::S3.stubs(:presigned_url).returns(thumb_url)
    latest_attachment = Helpdesk::Attachment.last
    match_json(attachment_pattern(latest_attachment))
  ensure
    Helpdesk::Attachment.any_instance.unstub(:valid_image?)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    AwsWrapper::S3.unstub(:presigned_url)
  end

  def test_unlink_attachment
    @controller.request.env['CONTENT_TYPE'] = 'application/json; charset=UTF-8'
    ticket = create_ticket
    create_shared_attachment(ticket)
    attachment = ticket.attachments_sharable.first
    params_hash = { attachable_id: ticket.display_id, attachable_type: 'ticket' }
    put :unlink, construct_params({ version: 'private', id: attachment.id }, params_hash)
    ticket.reload
    refute ticket.shared_attachments.present?
    assert_response 204
  end

  def test_unlink_attachment_with_invalid_id
    @controller.request.env['CONTENT_TYPE'] = 'application/json; charset=UTF-8'
    ticket_id = create_ticket.display_id
    attachment = create_attachment(attachable_type: 'Helpdesk::Ticket', attachable_id: ticket_id)
    params_hash = { attachable_id: 10_000, attachable_type: 'ticket' }
    put :unlink, construct_params({ version: 'private', id: attachment.id }, params_hash)
    assert_response 404
  end

  def test_show_attachment
    ticket = create_ticket
    attachment = create_attachment(attachable_type: 'Helpdesk::Ticket', attachable_id: ticket.id)
    get :show, construct_params(version: 'private', id: attachment.id)
    assert_response 200
    match_json(attachment_pattern(attachment))
  end

  def test_show_attachment_with_invalid_id
    get :show, construct_params(version: 'private', id: 10_000_001)
    assert_response 404
    assert_equal ' ', response.body
  end

  def test_show_attachment_without_ticket_permission
    ticket_id = create_ticket.id
    attachment = create_attachment(attachable_type: 'Helpdesk::Ticket', attachable_id: ticket_id)
    User.any_instance.stubs(:has_ticket_permission?).returns(false)
    get :show, construct_params(version: 'private', id: attachment.id)
    User.any_instance.unstub(:has_ticket_permission?)
    assert_response 403
  end

  def test_create_with_unicode_control_character_filename
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :create, construct_params({ version: 'private' }, attachment_unicode_params_hash)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 200
    latest_attachment = Helpdesk::Attachment.last
    match_json(attachment_pattern(latest_attachment))
    assert_equal latest_attachment.attachable_type, 'UserDraft'
    assert_equal latest_attachment.attachable_id, @agent.id
    p latest_attachment
    assert_equal latest_attachment.content_file_name, 'shib_E2_80_AE3pm.txt'
  end

  def test_create_jpeg_image_remove_image_meta_data
    Account.current.launch(:remove_image_attachment_meta_data)
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    Helpdesk::Attachment.any_instance.stubs(:valid_image?).returns(true)
    post :create, construct_params({ version: 'private' }, image_with_exif_attachment_params_hash)
    assert_response 200
    thumb_url = JSON.parse(response.body)['thumb_url']
    AwsWrapper::S3.stubs(:presigned_url).returns(thumb_url)
    latest_attachment = Helpdesk::Attachment.last
    match_json(attachment_pattern(latest_attachment))
  ensure
    Account.current.rollback(:remove_image_attachment_meta_data)
    Helpdesk::Attachment.any_instance.unstub(:valid_image?)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    AwsWrapper::S3.unstub(:presigned_url)
  end

  def test_image_meta_data_delete_worker
    input_file = 'test/api/fixtures/files/image_with_exif.jpg'
    file = File.open(input_file)
    file_content = file.read
    expected_file = File.open('test/api/fixtures/files/image_without_exif.jpg')
    expected_file_content = expected_file.read
    AwsWrapper::S3.stubs(:read).returns(file_content)
    AwsWrapper::S3.stubs(:put).returns(true)
    File.stubs(:delete).returns(true)
    args = { 's3_paths': [input_file], 's3_bucket': 'irrelevant' }
    ImageMetaDataDeleteWorker.new.perform(args)
    output_file_path = Dir[File.join(Dir.tmpdir, '**', 'image-attachments*')][0]
    output_file_content = File.open(output_file_path).read
    assert_equal expected_file_content, output_file_content
  ensure
    AwsWrapper::S3.unstub(:read)
    AwsWrapper::S3.unstub(:put)
    File.unstub(:delete)
    File.delete(output_file_path) if File.exists?(output_file_path)
    file.close
    expected_file.close
  end

  def test_image_meta_data_delete_worker_invalid_image
    input_file = 'test/api/fixtures/files/image_with_exif.jpg'
    file = File.open(input_file)
    file_content = file.read
    AwsWrapper::S3.stubs(:read).returns(file_content[0, 400])
    AwsWrapper::S3.stubs(:put).returns(true)
    SecureRandom.stubs(:uuid).returns('image_exif_mod')
    args = { 's3_paths': [input_file], 's3_bucket': 'irrelevant' }
    assert_raises StandardError do
      ImageMetaDataDeleteWorker.new.perform(args)
    end
  ensure
    AwsWrapper::S3.unstub(:read)
    AwsWrapper::S3.unstub(:put)
    SecureRandom.unstub(:uuid)
    file.close
  end
end
