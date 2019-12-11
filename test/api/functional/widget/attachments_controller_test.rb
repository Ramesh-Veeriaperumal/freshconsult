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
      log_out
      controller.class.any_instance.stubs(:api_current_user).returns(nil)
    end

    def teardown
      super
      controller.class.any_instance.unstub(:api_current_user)
    end

    def before_all
      @widget = create_widget
      @request.env['HTTP_X_WIDGET_ID'] = @widget.id
      @client_id = UUIDTools::UUID.timestamp_create.hexdigest
      @request.env['HTTP_X_CLIENT_ID'] = @client_id
      @request.env['CONTENT_TYPE'] = 'multipart/form-data'
      @account.launch :help_widget
    end

    def attachment_params_hash
      file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
      params_hash = { content: file }
    end

    def test_create_attachment_without_x_widget_auth
      @account.launch :help_widget_login
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

    def test_create_attachment_with_x_widget_auth_user_present
      @account.launch :help_widget_login
      timestamp = Time.zone.now.utc.iso8601
      User.any_instance.stubs(:agent?).returns(false)
      secret_key = SecureRandom.hex
      @account.stubs(:help_widget_secret).returns(secret_key)
      user = add_new_user(@account)
      auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: timestamp }, secret_key)
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
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
      assert_equal User.current.id, user.id
    ensure
      @account.rollback :help_widget_login
      User.any_instance.unstub(:agent?)
      @account.unstub(:help_widget_secret)
    end

    def test_create_attachment_with_x_widget_auth_user_absent
      @account.launch :help_widget_login
      timestamp = Time.zone.now.utc.iso8601
      User.any_instance.stubs(:agent?).returns(false)
      secret_key = SecureRandom.hex
      @account.stubs(:help_widget_secret).returns(secret_key)
      auth_token = JWT.encode({ name: 'Padmashri', email: 'praajiddslongbottom@freshworks.com', timestamp: timestamp }, secret_key)
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      post :create, construct_params({ version: 'widget' }, attachment_params_hash)
      DataTypeValidator.any_instance.unstub(:valid_type?)
      assert_response 404
    ensure
      @account.rollback :help_widget_login
      User.any_instance.unstub(:agent?)
      @account.unstub(:help_widget_secret)
    end

    def test_create_attachment_with_wrong_x_widget_auth
      @account.launch :help_widget_login
      timestamp = Time.zone.now.utc.iso8601
      User.any_instance.stubs(:agent?).returns(false)
      secret_key = SecureRandom.hex
      @account.stubs(:help_widget_secret).returns(secret_key)
      auth_token = JWT.encode({ name: 'Padmashri', email: 'praaji.longbottom@freshworks.com', timestamp: timestamp }, secret_key + 'opo')
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      post :create, construct_params({ version: 'widget' }, attachment_params_hash)
      assert_response 401
    ensure
      @account.rollback :help_widget_login
      User.any_instance.unstub(:agent?)
      @account.unstub(:help_widget_secret)
      DataTypeValidator.any_instance.unstub(:valid_type?)
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
      @account.rollback(:help_widget)
      post :create, construct_params({ version: 'widget' }, attachment_params_hash)
      assert_response 403
      @account.launch(:help_widget)
    end

    def test_create_attachment_without_help_widget_feature
      @account.remove_feature(:help_widget)
      post :create, construct_params({ version: 'widget' }, attachment_params_hash)
      assert_response 403
      @account.add_feature(:help_widget)
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

    def test_create_attachment_with_invalid_param
      post :create, construct_params({ version: 'widget' }, attachment_params_hash.merge(test: 1))
      assert_response 400
      match_json(validation_error_pattern(bad_request_error_pattern(:test, 'Unexpected/invalid field in request', code: 'invalid_field')))
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

    def test_create_with_login_required_without_auth_token
      HelpWidget.any_instance.stubs(:contact_form_require_login?).returns(true)
      @account.launch :help_widget_login
      post :create, construct_params({ version: 'widget' }, attachment_params_hash)
      assert_response 400
      match_json(request_error_pattern(:x_widget_auth_required, 'x_widget_auth_required'))
    ensure
      HelpWidget.any_instance.unstub(:contact_form_require_login?)
      @account.rollback(:help_widget_login)
    end
  end
end
