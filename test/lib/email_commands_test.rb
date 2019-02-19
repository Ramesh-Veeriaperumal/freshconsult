require_relative '../api/unit_test_helper'

class EmailCommandsTest < ActionView::TestCase
  include EmailCommands

  def setup
    @dummy_ticket = fetch_dummy_ticket
  end

  def fetch_dummy_ticket
    Helpdesk::Ticket.first
  end

  def test_valid_ticket_source
    computed_source = source(@dummy_ticket, 'email', nil, nil)
    assert_equal @dummy_ticket.source, computed_source
  end

  def test_invalid_ticket_source
    computed_source = source(@dummy_ticket, 'emai', nil, nil)
    assert_equal nil, computed_source
  end

  def test_valid_ticket_type
    computed_type = type(@dummy_ticket, 'Question', nil, nil)
    assert_equal @dummy_ticket.ticket_type, computed_type
  end

  def test_invalid_ticket_type
    computed_type = type(@dummy_ticket, 'Q', nil, nil)
    assert_equal nil, computed_type
  end

  def test_valid_ticket_status
    computed_status = status(@dummy_ticket, 'Open', nil, nil)
    assert_equal @dummy_ticket.status, computed_status
  end

  def test_invalid_ticket_status
    computed_status = status(@dummy_ticket, 'O', nil, nil)
    assert_equal nil, computed_status
  end

  def test_valid_ticket_priority
    computed_priority = priority(@dummy_ticket, 'low', nil, nil)
    assert_equal @dummy_ticket.priority, computed_priority
  end

  def test_invalid_ticket_priority
    computed_priority = priority(@dummy_ticket, 'lsdfadsf', nil, nil)
    assert_equal nil, computed_priority
  end

  def test_invalid_ticket_group
    computed_group = group(@dummy_ticket, 'asdf', nil, nil)
    assert_equal nil, computed_group
  end

  def test_valid_ticket_action
    dummy_note = @dummy_ticket.notes.last
    computed_note = action(nil, 'note', nil, dummy_note)
    assert_equal dummy_note.source, computed_note
  end

  def test_invalid_ticket_action
    dummy_note = @dummy_ticket.notes.last
    computed_note = action(nil, 'n', nil, dummy_note)
    assert_equal nil, computed_note
  end

  def test_valid_ticket_agent
    dummy_user = @dummy_ticket.responder
    computed_agent = agent(@dummy_ticket, 'me', dummy_user, nil)
    assert_equal @dummy_ticket.responder, computed_agent
  end

  def test_invalid_ticket_agent
    dummy_user = @dummy_ticket.responder
    computed_agent = agent(@dummy_ticket, 'asdfe', dummy_user, nil)
    @dummy_ticket.responder = dummy_user
    assert_equal nil, computed_agent
  end

  def test_invalid_ticket_product
    computed_product = product(@dummy_ticket, 'asdf', nil, nil)
    assert_equal nil, computed_product
  end

  def test_process_email_commands_errors
    dummy_user = User.first
    email_param = HashWithIndifferentAccess.new
    EmailCommandsTest.any_instance.stubs(:get_email_cmd_regex).raises(Exception.new('sample exception in test case'))
    email_param[:text] = 'hello'
    processed_command = process_email_commands(@dummy_ticket, dummy_user, nil, email_param, nil)
    assert_equal true, processed_command
  end

  def test_process_email_commands_with_valid_text
    dummy_user = User.first
    email_param = HashWithIndifferentAccess.new
    email_param[:text] = '@Simonsays@Simonsays'
    processed_command = process_email_commands(@dummy_ticket, dummy_user, nil, email_param, nil)
    assert_equal nil, processed_command
  end
end
