require_relative '../unit_test_helper'

class FbReplyValidationTest < ActionView::TestCase
  def setup
    Account.stubs(:current).returns(Account.first)
  end

  def teardown
    Account.unstub(:current)
  end

  def test_numericality_for_dm
    controller_params = { 'body' => 'XYZ', 'note_id' => 'XYZ', 'agent_id' => 'XYZ' }
    fb_reply_validation = FbReplyValidation.new(controller_params, nil)
    refute fb_reply_validation.valid?
    errors = fb_reply_validation.errors.full_messages
    assert errors.include?('Note datatype_mismatch')
    assert errors.include?('Agent datatype_mismatch')

    controller_params = { 'body' => 'XYZ', 'note_id' => 1, 'agent_id' => 1, 'msg_type' => Facebook::Constants::FB_MSG_TYPES[0] }
    fb_reply_validation = FbReplyValidation.new(controller_params, nil)
    assert fb_reply_validation.valid?
  end

  def test_numericality_for_post
    controller_params = { 'body' => 'XYZ', 'note_id' => 'XYZ', 'agent_id' => 'XYZ' }
    fb_reply_validation = FbReplyValidation.new(controller_params, nil)
    refute fb_reply_validation.valid?
    errors = fb_reply_validation.errors.full_messages
    assert errors.include?('Note datatype_mismatch')
    assert errors.include?('Agent datatype_mismatch')

    controller_params = { 'body' => 'XYZ', 'note_id' => 1, 'agent_id' => 1, 'msg_type' => Facebook::Constants::FB_MSG_TYPES[1] }
    fb_reply_validation = FbReplyValidation.new(controller_params, nil)
    assert fb_reply_validation.valid?
  end

  def test_body_for_dm
    controller_params = { 'body' => 'XYZ', 'msg_type' => Facebook::Constants::FB_MSG_TYPES[0] }
    fb_reply_validation = FbReplyValidation.new(controller_params, nil)
    assert fb_reply_validation.valid?
  end

  def test_body_for_post
    controller_params = { 'body' => 'XYZ', 'msg_type' => Facebook::Constants::FB_MSG_TYPES[1] }
    fb_reply_validation = FbReplyValidation.new(controller_params, nil)
    assert fb_reply_validation.valid?
  end

  def test_attachment_for_dm
    controller_params = { 'attachment_ids' => [1], 'msg_type' => Facebook::Constants::FB_MSG_TYPES[0] }
    fb_reply_validation = FbReplyValidation.new(controller_params, nil)
    assert fb_reply_validation.valid?
  end

  def test_attachment_for_post
    controller_params = { 'attachment_ids' => [1], 'msg_type' => Facebook::Constants::FB_MSG_TYPES[1] }
    fb_reply_validation = FbReplyValidation.new(controller_params, nil)
    assert fb_reply_validation.valid?
  end

  def test_ticket_validation_for_dm
    controller_params = { 'body' => 'XYZ', 'msg_type' => Facebook::Constants::FB_MSG_TYPES[0] }
    item = Helpdesk::Ticket.new(subject: Faker::Lorem.word, description: Faker::Lorem.paragraph, source: 1, requester_id: 5)
    fb_reply_validation = FbReplyValidation.new(controller_params, item)
    refute fb_reply_validation.valid?
    assert fb_reply_validation.errors.full_messages.include?('Ticket not_a_facebook_ticket')

    item.source = Account.current.helpdesk_sources.ticket_source_keys_by_token[:facebook]
    fb_reply_validation = FbReplyValidation.new(controller_params, item)
    assert fb_reply_validation.valid?
  end

  def test_ticket_validation_for_post
    controller_params = { 'body' => 'XYZ', 'msg_type' => Facebook::Constants::FB_MSG_TYPES[1] }
    item = Helpdesk::Ticket.new(subject: Faker::Lorem.word, description: Faker::Lorem.paragraph, source: 1, requester_id: 5)
    fb_reply_validation = FbReplyValidation.new(controller_params, item)
    refute fb_reply_validation.valid?
    assert fb_reply_validation.errors.full_messages.include?('Ticket not_a_facebook_ticket')

    item.source = Account.current.helpdesk_sources.ticket_source_keys_by_token[:facebook]
    fb_reply_validation = FbReplyValidation.new(controller_params, item)
    assert fb_reply_validation.valid?
  end

  def test_failure_both_body_attachment_ids_present_for_dm
    controller_params = { 'body' => 'XYZ', 'note_id' => 1, 'agent_id' => 1, 'msg_type' => Facebook::Constants::FB_MSG_TYPES[0], 'attachment_ids' => [1] }
    fb_reply_validation = FbReplyValidation.new(controller_params, nil)
    refute fb_reply_validation.valid?
    assert fb_reply_validation.errors.full_messages.include?('Attachment ids can_have_only_one_field')
  end

  def test_failure_both_body_attachment_ids_not_present_for_dm
    controller_params = { 'note_id' => 1, 'agent_id' => 1, 'msg_type' => Facebook::Constants::FB_MSG_TYPES[0] }
    fb_reply_validation = FbReplyValidation.new(controller_params, nil)
    refute fb_reply_validation.valid?
    assert fb_reply_validation.errors.full_messages.include?('Body missing_field')
  end

  def test_failure_both_body_attachment_ids_not_present_for_post
    controller_params = { 'note_id' => 1, 'agent_id' => 1, 'msg_type' => Facebook::Constants::FB_MSG_TYPES[0] }
    fb_reply_validation = FbReplyValidation.new(controller_params, nil)
    refute fb_reply_validation.valid?
    assert fb_reply_validation.errors.full_messages.include?('Body missing_field')
  end

  def test_msg_type_for_dm
    controller_params = { body: 'abc', msg_type: Facebook::Constants::FB_MSG_TYPES[0] }
    fb_reply_validation = FbReplyValidation.new(controller_params, nil)
    assert fb_reply_validation.valid?
  end

  def test_msg_type_for_post
    controller_params = { body: 'abc', msg_type: Facebook::Constants::FB_MSG_TYPES[1] }
    fb_reply_validation = FbReplyValidation.new(controller_params, nil)
    assert fb_reply_validation.valid?
  end

  def test_invalid_msg_type
    controller_params = { body: 'abc', msg_type: 'xyz' }
    fb_reply_validation = FbReplyValidation.new(controller_params, nil)
    refute fb_reply_validation.valid?
  end

  def test_with_invalid_include_surveymonkey_link
    controller_params = { body: 'abc', msg_type: 'dm', include_surveymonkey_link: 2 }
    fb_reply_validation = FbReplyValidation.new(controller_params, nil)
    refute fb_reply_validation.valid?
    assert fb_reply_validation.errors.full_messages.include?('Include surveymonkey link is not included in the list')
  end
end
