require_relative '../../../test_helper'
require Rails.root.join('spec', 'support', 'account_helper.rb')
require Rails.root.join('test', 'lib', 'helpers', 'channel_reply_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'note_test_helper.rb')
require Rails.root.join('test', 'lib', 'helpers', 'contact_segments_test_helper.rb')
class TwitterTest < ActionView::TestCase
  include AccountHelper
  include ChannelReplyTestHelper
  include NoteTestHelper
  include ContactSegmentsTestHelper

  def setup
    @account = Account.first || create_test_account
    Account.stubs(:current).returns(@account)
    @user = account.users.first || create_contact
  end

  def teardown
    super
    Account.unstub(:current)
  end

  def test_send_survey_twitter_dm_with_error
    twitter_reply_service = ChannelIntegrations::Replies::Services::Twitter.new
    note = create_note(source: Account.current.helpdesk_sources.note_source_keys_by_token['twitter'], user_id: @user.id)
    payload = construct_twitter_reply_payload_with_error(note.id)
    twitter_reply_service.send_survey_twitter_dm(payload)
    schema_less_notes = Account.current.schema_less_notes.reload.last
    assert_equal schema_less_notes.note_properties[:errors][:twitter][:code], ChannelIntegrations::Constants::SURVEY_DM_ERROR_CODE
  ensure
    note.destroy
  end

  def test_send_survey_twitter_dm_with_twitter_error_present
    twitter_reply_service = ChannelIntegrations::Replies::Services::Twitter.new
    note = create_note(source: Account.current.helpdesk_sources.note_source_keys_by_token['twitter'], user_id: @user.id)
    schema_less_note = Account.current.schema_less_notes.reload.last
    twitter_errors = { twitter: { error_code: 403, error_message: 'twitter error', code: 103 } }
    schema_less_note.note_properties[:errors] ||= {}
    schema_less_note.note_properties[:errors].merge!(twitter_errors)
    schema_less_note.save!
    payload = construct_twitter_reply_payload_with_error(note.id)
    twitter_reply_service.send_survey_twitter_dm(payload)
    schema_less_notes = Account.current.schema_less_notes.reload.last
    assert_equal schema_less_notes.note_properties[:errors][:twitter][:code], 103
    assert_equal schema_less_notes.note_properties[:errors][:twitter][:error_code], 403
    assert_equal schema_less_notes.note_properties[:errors][:twitter][:error_message], 'twitter error'
  ensure
    note.destroy
  end

  def test_send_survey_twitter_dm_when_note_id_missing
    twitter_reply_service = ChannelIntegrations::Replies::Services::Twitter.new
    payload = construct_twitter_reply_payload_with_error(nil)
    response = twitter_reply_service.send_survey_twitter_dm(payload)
    assert_nil response
  end

  def test_send_survey_twitter_dm_when_note_missing
    twitter_reply_service = ChannelIntegrations::Replies::Services::Twitter.new
    note_id = Faker::Number.number(12)
    payload = construct_twitter_reply_payload_with_error(note_id)
    response = twitter_reply_service.send_survey_twitter_dm(payload)
    assert_nil response
  end
end
