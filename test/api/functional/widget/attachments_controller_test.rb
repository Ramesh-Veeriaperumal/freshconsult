require_relative '../../test_helper'
module Widget
  class AttachmentsControllerTest < ActionController::TestCase
    include AttachmentsTestHelper
    include HelpWidgetsTestHelper

    def wrap_cname(params)
      { attachment: params }
    end

    def setup
      super
      before_all
    end

    def before_all
      @widget = create_widget
      @request.env['HTTP_X_WIDGET_ID'] = @widget.id
      @request.env['CONTENT_TYPE'] = 'multipart/form-data'
      @account.launch :help_widget
    end

    def attachment_params_hash
      file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
      params_hash = { content: file }
    end

    def test_create_attachment
      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      post :create, construct_params({ version: 'widget' }, attachment_params_hash)
      DataTypeValidator.any_instance.unstub(:valid_type?)
      assert_response 200
      latest_attachment = Helpdesk::Attachment.last
      match_json(id: latest_attachment.id)
      assert_equal latest_attachment.attachable_type, 'UserDraft'
    end

    def test_create_attachment_with_contact_form_disabled
      @widget.settings[:components][:contact_form] = false
      @widget.save
      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      post :create, construct_params({ version: 'widget' }, attachment_params_hash)
      DataTypeValidator.any_instance.unstub(:valid_type?)
      assert_response 400
      match_json(request_error_pattern(:contact_form_not_enabled, 'contact_form_not_enabled'))
    end

    def test_attachment_invalid_size_create
      invalid_attachment_limit = @account.attachment_limit + 2
      Rack::Test::UploadedFile.any_instance.stubs(:size).returns(invalid_attachment_limit.megabytes)
      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      post :create, construct_params({ version: 'widget' }, attachment_params_hash)
      DataTypeValidator.any_instance.unstub(:valid_type?)
      assert_response 400
      match_json([bad_request_error_pattern(:content, :invalid_size, max_size: "#{@account.attachment_limit} MB", current_size: "#{invalid_attachment_limit} MB")])
    end

    def test_attachment_without_widget_id
      @request.env['HTTP_X_WIDGET_ID'] = nil
      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      post :create, construct_params({ version: 'widget' }, attachment_params_hash)
      DataTypeValidator.any_instance.unstub(:valid_type?)
      assert_response 400
    end

    def test_create_attachment_with_user_id
      post :create, construct_params({ version: 'widget' }, attachment_params_hash.merge(user_id: 1))
      assert_response 400
      match_json(validation_error_pattern(bad_request_error_pattern(:user_id, 'Unexpected/invalid field in request', code: 'invalid_field')))
    end

    def test_create_attachment_without_content
      post :create, construct_params({ version: 'widget' }, {})
      assert_response 400
      match_json([bad_request_error_pattern('content', :missing_field)])
    end

    def test_create_with_invalid_params
      post :create, construct_params(version: 'widget', content: 'XYZ')
      match_json([bad_request_error_pattern('content', :datatype_mismatch, expected_data_type: 'valid file format', prepend_msg: :input_received, given_data_type: String)])
      assert_response 400
    end

    def test_create_with_errors
      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      Helpdesk::Attachment.any_instance.stubs(:save).returns(false)
      post :create, construct_params({ version: 'widget' }, attachment_params_hash)
      DataTypeValidator.any_instance.unstub(:valid_type?)
      Helpdesk::Attachment.any_instance.unstub(:save)
      assert_response 500
    end
  end
end
