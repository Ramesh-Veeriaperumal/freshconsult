require_relative '../unit_test_helper'

class FbReplyValidationTest < ActionView::TestCase
  def test_numericality
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
    controller_params = { 'body' => '' }
    fb_reply_validation = FbReplyValidation.new(controller_params, nil)
    refute fb_reply_validation.valid?
    assert fb_reply_validation.errors.full_messages.include?('Body blank')
  end

  def test_ticket_validation
    controller_params = { 'body' => 'XYZ' }
    item = Helpdesk::Ticket.new(subject: Faker::Lorem.word, description: Faker::Lorem.paragraph, source: 1, requester_id: 5)
    fb_reply_validation = FbReplyValidation.new(controller_params, item)
    refute fb_reply_validation.valid?
    assert fb_reply_validation.errors.full_messages.include?('Ticket not_a_facebook_ticket')

    item.source = TicketConstants::SOURCE_KEYS_BY_TOKEN[:facebook]
    fb_reply_validation = FbReplyValidation.new(controller_params, item)
    assert fb_reply_validation.valid?
  end
end
