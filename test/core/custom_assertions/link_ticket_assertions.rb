module LinkTicketAssertions

  def assert_link_ticket(tracker,related_ticket_ids)
    redirect_path = related_ticket_ids.count > 1 ? helpdesk_tickets_path : 
                          helpdesk_ticket_path(related_ticket_ids.first)
    assert_redirected_to redirect_path, "Expected redirected to #{redirect_path}"
    stub_ticket_associates(related_ticket_ids, tracker) do
      assert_tracker(tracker, related_ticket_ids)
      related_ticket_ids.each do |rid|
        related = @account.tickets.find_by_display_id(rid)
        assert_related_ticket tracker,related
      end
    end
  end

  def assert_related_ticket(tracker, related)
    assert related.related_ticket?, "Expected #{related.display_id} to be a Related ticket"
    assert_equal tracker.display_id, related.associated_prime_ticket("related").display_id    
  end

  def assert_tracker(tracker,related_ticket_ids=nil)
    assert tracker.tracker_ticket?, "Expected #{tracker.display_id} to be a Tracker"  
    related_ticket_ids.each do |r|
      message = "Expected #{r} linked to Tracker #{tracker.display_id}"
      assert_includes tracker.associated_subsidiary_tickets("tracker").pluck(:display_id), r, message
    end if related_ticket_ids
  end

  def assert_not_related(tracker, ticket)
    assert !ticket.related_ticket?, "Expected #{ticket.display_id} not to be a Related ticket"
    assert_nil ticket.associated_prime_ticket("related")
  end

  def assert_tracker_deleted(tracker, related_ticket_ids, broadcast_note_id)
    assert tracker.spam_or_deleted?, "Expected #{tracker.display_id} not to be a deleted"
    related_ticket_ids.each {|id| assert_not_related(tracker, Helpdesk::Ticket.find_by_display_id(id))}
    assert_nil Helpdesk::Note.find_by_id(broadcast_note_id)
    assert_empty @account.broadcast_messages.where(:tracker_display_id => tracker.display_id)
  end

  def assert_related_deleted(ticket)
    assert ticket.spam_or_deleted?
    assert !ticket.related_ticket?
  end

  alias_method :assert_tracker_spammed, :assert_tracker_deleted
  alias_method :assert_related_spammed, :assert_related_deleted

end