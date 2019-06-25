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
      @client_id = UUIDTools::UUID.timestamp_create.hexdigest
      @request.env['HTTP_X_CLIENT_ID'] = @client_id
      @request.env['CONTENT_TYPE'] = 'multipart/form-data'
      @account.launch :help_widget
      @account.add_feature(:anonymous_tickets)
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
      assert_equal latest_attachment.attachable_id, @widget.id
      assert_equal latest_attachment.attachable_type, 'WidgetDraft'
      assert_equal latest_attachment.description, @client_id.to_s
      assert_equal latest_attachment.attachable, @widget
    end

    def test_create_attachment_without_help_widget_launch
      Account.any_instance.stubs(:all_launched_features).returns([])
      post :create, construct_params({ version: 'widget' }, attachment_params_hash)
      assert_response 403
      Account.any_instance.unstub(:all_launched_features)
    end

    def test_create_attachment_without_anonymous_tickets
      @widget.settings[:components][:contact_form] = false
      @widget.save
      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      Account.any_instance.stubs(:features?).with(:anonymous_tickets).returns(false)
      post :create, construct_params({ version: 'widget' }, attachment_params_hash)
      DataTypeValidator.any_instance.unstub(:valid_type?)
      assert_response 403
      Account.any_instance.unstub(:features?)
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
