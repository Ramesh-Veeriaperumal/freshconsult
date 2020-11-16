require_relative '../test_helper'
require_relative '../../api/unit_test_helper'
require_relative '../../../spec/support/note_helper'
require_relative '../../api/helpers/test_class_methods.rb'
require_relative '../../api/helpers/tickets_test_helper.rb'
['account_helper.rb', 'user_helper.rb'].each { |file| require Rails.root.join('spec', 'support', file) }

class NoteBodyTest < ActiveSupport::TestCase
  include AccountHelper
  include NoteHelper
  include UsersHelper
  include TicketsTestHelper

  def setup
    super
    @account = create_new_account('redaction') if @account.nil?
    @body= 'hello MasterCard  5500 0000 0000 0004'
    @redacted_body = 'hello MasterCard  XXXX XXXX XXXX 0004'
    Account.any_instance.stubs(:redaction_enabled?).returns(true)
    AccountAdditionalSettings.any_instance.stubs(:redaction).returns(credit_card_number: true)
  end

  def teardown
    super
    Account.unstub(:current)
    Account.any_instance.unstub(:redaction_enabled?)
    AccountAdditionalSettings.any_instance.unstub(:redaction)
  end

  def test_note_body_redaction
    user = add_new_user(@account)
    ticket = create_ticket(requester_id: user.id)
    test_note = create_note(notable_id: ticket.id, body: @body, user_id: ticket.requester_id)
    assert test_note.body.include?(@redacted_body)
    assert test_note.body_html.include?(@redacted_body)
  end

  def test_note_body_redaction_with_callback
    user = add_new_user(@account)
    ticket = create_ticket(requester_id: user.id)
    note_body = ticket.notes.first.note_body
    note_body.redaction_processed = false
    note_body.body_html = @body
    note_body.save!
    note_body.reload
    assert note_body.body_html.include?(@redacted_body)
  end

  def test_note_body_redaction_agent_as_requester
    agent = add_agent(@account)
    ticket = create_ticket(requester_id: agent.id)
    test_note = create_note(notable_id: ticket.id, body: @body, user_id: ticket.requester_id)
    refute test_note.body.include?(@redacted_body)
    refute test_note.body_html.include?(@redacted_body)
    assert test_note.body.include?(@body)
    assert test_note.body_html.include?(@body)
  end

  def test_note_body_with_credit_card_redaction_off
    AccountAdditionalSettings.any_instance.stubs(:redaction).returns(credit_card_number: false)
    user = add_new_user(@account)
    ticket = create_ticket(requester_id: user.id)
    test_note = create_note(notable_id: ticket.id, body: @body, user_id: ticket.requester_id)
    refute test_note.body.include?(@redacted_body)
    refute test_note.body_html.include?(@redacted_body)
  end

  def test_note_body_redaction_without_feature
    Account.any_instance.stubs(:redaction_enabled?).returns(false)
    user = add_new_user(@account)
    ticket = create_ticket(requester_id: user.id)
    test_note = create_note(notable_id: ticket.id, body: @body, user_id: ticket.requester_id)
    refute test_note.body.include?(@redacted_body)
    refute test_note.body_html.include?(@redacted_body)
  end
end
