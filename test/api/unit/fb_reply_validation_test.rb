require_relative '../unit_test_helper'

class FbReplyValidationTest < ActionView::TestCase
  def setup
    Account.stubs(:current).returns(Account.first)
  end

  def teardown
    Account.unstub(:current)
  end

  def test_numericality
    FbReplyValidation.any_instance.stubs(:facebook_outgoing_attachment_enabled?).returns(false)
    controller_params = { 'body' => 'XYZ', 'note_id' => 'XYZ', 'agent_id' => 'XYZ' }
    fb_reply_validation = FbReplyValidation.new(controller_params, nil)
    refute fb_reply_validation.valid?
    errors = fb_reply_validation.errors.full_messages
    assert errors.include?('Note datatype_mismatch')
    assert errors.include?('Agent datatype_mismatch')

    controller_params = { 'body' => 'XYZ', 'note_id' => 1, 'agent_id' => 1 }
    fb_reply_validation = FbReplyValidation.new(controller_params, nil)
    assert fb_reply_validation.valid?
  end

  def test_body
    FbReplyValidation.any_instance.stubs(:facebook_outgoing_attachment_enabled?).returns(false)
    controller_params = { 'body' => '' }
    fb_reply_validation = FbReplyValidation.new(controller_params, nil)
    refute fb_reply_validation.valid?
    assert fb_reply_validation.errors.full_messages.include?('Body blank')
  end

  def test_ticket_validation
    FbReplyValidation.any_instance.stubs(:facebook_outgoing_attachment_enabled?).returns(false)
    controller_params = { 'body' => 'XYZ' }
    item = Helpdesk::Ticket.new(subject: Faker::Lorem.word, description: Faker::Lorem.paragraph, source: 1, requester_id: 5)
    fb_reply_validation = FbReplyValidation.new(controller_params, item)
    refute fb_reply_validation.valid?
    assert fb_reply_validation.errors.full_messages.include?('Ticket not_a_facebook_ticket')

    item.source = Account.current.helpdesk_sources.ticket_source_keys_by_token[:facebook]
    fb_reply_validation = FbReplyValidation.new(controller_params, item)
    assert fb_reply_validation.valid?
  end

  def test_failure_both_body_attachment_ids_present
    FbReplyValidation.any_instance.stubs(:facebook_outgoing_attachment_enabled?).returns(true)
    controller_params = { 'body' => 'XYZ', 'note_id' => 1, 'agent_id' => 1, 'msg_type' => 'dm', 'attachment_ids' => [1] }
    fb_reply_validation = FbReplyValidation.new(controller_params, nil)
    refute fb_reply_validation.valid?
    assert fb_reply_validation.errors.full_messages.include?('Attachment ids can_have_only_one_field')
  end

  def test_msg_type
    FbReplyValidation.any_instance.stubs(:facebook_outgoing_attachment_enabled?).returns(true)
    controller_params = { body: 'abc', msg_type: Facebook::Constants::FB_MSG_TYPES[0] }
    fb_reply_validation = FbReplyValidation.new(controller_params, nil)
    assert fb_reply_validation.valid?
  end

  def test_invalid_msg_type
    FbReplyValidation.any_instance.stubs(:facebook_outgoing_attachment_enabled?).returns(true)
    controller_params = { body: 'abc', msg_type: 'xyz' }
    fb_reply_validation = FbReplyValidation.new(controller_params, nil)
    refute fb_reply_validation.valid?
  end

  def test_with_invalid_include_surveymonkey_link
    FbReplyValidation.any_instance.stubs(:facebook_outgoing_attachment_enabled?).returns(true)
    controller_params = { body: 'abc', msg_type: 'xyz', include_surveymonkey_link: 2 }
    fb_reply_validation = FbReplyValidation.new(controller_params, nil)
    refute fb_reply_validation.valid?
    assert fb_reply_validation.errors.full_messages.include?('Include surveymonkey link is not included in the list')
  ensure
    FbReplyValidation.any_instance.unstub(:facebook_outgoing_attachment_enabled)
  end
end
