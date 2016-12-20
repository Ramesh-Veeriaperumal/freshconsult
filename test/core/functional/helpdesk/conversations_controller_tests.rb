require_relative '../../test_helper'
Dir["#{Rails.root}/test/core/functional/helpdesk/conversation_test_cases/*.rb"].each { |file| require file }

class Helpdesk::ConversationsControllerTest < ActionController::TestCase

#include helpers
  include TicketsTestHelper
  include DynamoTestHelper
  include LinkTicketAssertions
  include NoteTestHelper

  def setup
    super
    login_admin
  end

  def test_add_broadcast_note
    enable_link_tickets do
      related_ticket_ids = create_link_tickets
      tracker = Helpdesk::Ticket.last
      stub_ticket_associates(related_ticket_ids, tracker) do
        post :broadcast, broadcast_note_params(:ticket_id => tracker.display_id)
        assert tracker.notes.broadcast_notes.present?
        assert_present @account.broadcast_messages.where(:tracker_display_id => tracker.display_id)
      end
    end
  end

end