require_relative '../../../test_helper'
require Rails.root.join('test', 'lib', 'helpers', 'channel_reply_test_helper')
require Rails.root.join('spec', 'support', 'account_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'note_test_helper.rb')

module ChannelIntegrations::Replies::Services
  class FacebookTest < ActionView::TestCase
    include AccountHelper
    include ChannelReplyTestHelper
    include NoteTestHelper

    def setup
      @account = Account.first || create_test_account
      @user = @account.users.first
      Account.stubs(:current).returns(@account)
    end

    def teardown
      super
      Account.unstub(:current)
    end

    def test_receive_sm_facebook_update_schemaless_notes
      note = create_note(source: @account.helpdesk_sources.note_source_keys_by_token['facebook'], user_id: @user.id)
      payload = construct_facebook_response_payload(false, note.id, error_code: 190, error_message: 'Access token expired')
      facebook_reply_service = ChannelIntegrations::Replies::Services::Facebook.new
      result = facebook_reply_service.send_survey_facebook_dm(payload)
      schema_less_note = @account.schema_less_notes.reload.last
      schema_less_note_fb_errors = schema_less_note.note_properties.try(:[], :errors).try(:[], :facebook)
      assert_equal ChannelIntegrations::Constants::SURVEY_DM_ERROR_CODE, schema_less_note_fb_errors.try(:[], :code)
      assert_equal 190, schema_less_note_fb_errors.try(:[], :error_code)
      assert_equal 'Access token expired', schema_less_note_fb_errors.try(:[], :error_message)
    ensure
      note.destroy
    end

    def test_receive_sm_facebook_no_update_schemaless_notes
      note = create_note(source: @account.helpdesk_sources.note_source_keys_by_token['facebook'], user_id: @user.id)
      schema_less_note = @account.schema_less_notes.reload.last
      fb_errors = { facebook: { error_code: 404, error_message: 'Some error occurred' } }
      schema_less_note.note_properties[:errors] ||= {}
      schema_less_note.note_properties[:errors].merge!(fb_errors)
      schema_less_note.save!
      payload = construct_facebook_response_payload(false, note.id, error_code: 190, error_message: 'Access token expired')
      facebook_reply_service = ChannelIntegrations::Replies::Services::Facebook.new
      result = facebook_reply_service.send_survey_facebook_dm(payload)
      schema_less_note_fb_errors = schema_less_note.note_properties.try(:[], :errors).try(:[], :facebook)
      assert_equal 404, schema_less_note_fb_errors.try(:[], :error_code)
      assert_equal 'Some error occurred', schema_less_note_fb_errors.try(:[], :error_message)
      assert_nil schema_less_note_fb_errors.try(:[], :code)
    ensure
      note.destroy
    end

    def test_receive_sm_facebook_note_id_missing
      payload = construct_facebook_response_payload
      facebook_reply_service = ChannelIntegrations::Replies::Services::Facebook.new
      result = facebook_reply_service.send_survey_facebook_dm(payload)
      assert_nil result
    end

    def test_receive_sm_facebook_schemaless_note_not_found
      note_id = Faker::Number.number(15)
      payload = construct_facebook_response_payload(false, note_id)
      facebook_reply_service = ChannelIntegrations::Replies::Services::Facebook.new
      result = facebook_reply_service.send_survey_facebook_dm(payload)
      assert_nil result
    end
  end
end
