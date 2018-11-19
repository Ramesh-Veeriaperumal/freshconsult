require_relative '../../test_helper'
['ticket_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module Channel
  class AttachmentsControllerTest < ActionController::TestCase
    include AttachmentsTestHelper
    include TicketHelper

    def wrap_cname(params)
      { attachment: params }
    end

    def setup
      super
    end

    def set_content_type(type)
      request.env['CONTENT_TYPE'] = type
    end

    def attachment_params_hash
      file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
      params_hash = { user_id: @agent.id, content: file }
    end

    def test_create_attachments
      set_jwt_auth_header('twitter')
      set_content_type('multipart/form-data')

      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      post :create, construct_params({ version: 'channel' }, attachment_params_hash)
      DataTypeValidator.any_instance.unstub(:valid_type?)

      assert_response 200
      latest_attachment = Helpdesk::Attachment.last
      match_json(attachment_pattern(latest_attachment))
    end

    def test_create_attachments_should_fail_without_token
      set_content_type('multipart/form-data')
      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      post :create, construct_params({ version: 'channel' }, attachment_params_hash)
      DataTypeValidator.any_instance.unstub(:valid_type?)

      assert_response 401
    end

    def test_create_attachments_with_invalid_type
      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      post :create, construct_params({ version: 'channel' }, attachment_params_hash)
      DataTypeValidator.any_instance.unstub(:valid_type?)

      assert_response 415
    end

    def test_show_attachment
      set_jwt_auth_header('twitter')
      set_content_type('multipart/form-data')
      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      post :create, construct_params({ version: 'channel' }, attachment_params_hash)
      DataTypeValidator.any_instance.unstub(:valid_type?)
      latest_attachment = Helpdesk::Attachment.last
      get :show, controller_params(version: 'channel', id: latest_attachment.id)
      assert_equal response.headers.include?('Location'), true
      assert_response 302
    end

    def test_show_attachment_should_error_on_unauthorized_header
      set_content_type('multipart/form-data')
      set_jwt_auth_header('twitter')
      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      post :create, construct_params({ version: 'channel' }, attachment_params_hash)
      DataTypeValidator.any_instance.unstub(:valid_type?)
      latest_attachment = Helpdesk::Attachment.last
      request.env['X-Channel-Auth'] = nil
      get :show, controller_params(version: 'channel', id: latest_attachment.id)
      assert_response 401
    end

  end
end
