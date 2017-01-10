module LinkTicketTests

  def test_tracker_create_with_one_related
    enable_link_tickets do
      create_ticket
      display_id = Helpdesk::Ticket.last.display_id
      #stubbing dynamo db
      stub_ticket_associates([display_id]) do
        post :create, ticket_params_hash(:email => @agent.email, display_ids: "#{display_id}")
        tracker = Helpdesk::Ticket.last
        #assert linking impacts
        assert_link_ticket tracker, [display_id]
      end
    end
  end

  def test_tracker_create_with_multiple_related
    enable_link_tickets do
      related_ticket_ids = 5.times.collect { create_ticket.display_id }
      stub_ticket_associates(related_ticket_ids) do
        Sidekiq::Testing.inline! do
          post :create, ticket_params_hash(:email => @agent.email, display_ids: "#{related_ticket_ids.join(',')}")
          tracker = Helpdesk::Ticket.last
          assert_link_ticket tracker, related_ticket_ids
        end
      end
    end
  end

  def test_link_one_ticket_to_tracker
    enable_link_tickets do
      related_ticket_ids = create_link_tickets
      tracker = Helpdesk::Ticket.last
      create_ticket
      ticket = Helpdesk::Ticket.last
      # link this to the tracker
      stub_ticket_associates(related_ticket_ids << ticket.display_id, tracker) do
        put :link, {:id => ticket.display_id, :tracker_id => tracker.display_id}
        assert_related_ticket(tracker, ticket)
        assert_tracker(tracker, [ticket.display_id])
      end
    end
  end

  def test_multiple_link_to_tracker
    enable_link_tickets do
      related_ticket_ids = create_link_tickets
      tracker = Helpdesk::Ticket.last
      tickets_to_link = 5.times.collect { create_ticket.display_id }
      Sidekiq::Testing.inline! do
        stub_ticket_associates(related_ticket_ids + tickets_to_link, tracker) do
          put :link, {:id => "multiple", :ids => tickets_to_link, :tracker_id => tracker.display_id}
          assert_tracker(tracker, related_ticket_ids + tickets_to_link)
          tickets_to_link.each {|r| assert_related_ticket(tracker, Helpdesk::Ticket.find_by_display_id(r))}
        end
      end
    end
  end

  def test_unlink_from_tracker
    enable_link_tickets do
      related_ticket_ids = create_link_tickets
      tracker = Helpdesk::Ticket.last
      related_id = related_ticket_ids.shift
      Sidekiq::Testing.inline! do
        stub_ticket_associates(related_ticket_ids, tracker) do
          put :unlink, {:id => related_id, :tracker => false, :tracker_id => tracker.display_id}
          assert_not_related(tracker, Helpdesk::Ticket.find_by_display_id(related_id))
        end
      end
    end
  end

  def test_delete_tracker
    enable_link_tickets do
      related_ticket_ids = create_link_tickets
      tracker = Helpdesk::Ticket.last
      broadcast_note = create_broadcast_note(:notable_id => tracker.id)
      Sidekiq::Testing.inline! do
        stub_ticket_associates(related_ticket_ids, tracker) do
          delete :destroy, {:id => tracker.display_id }
          tracker.reload
          assert_tracker_deleted tracker, related_ticket_ids, broadcast_note.id
        end
      end
    end
  end

  def test_spam_tracker
    enable_link_tickets do
      related_ticket_ids = create_link_tickets
      tracker = Helpdesk::Ticket.last
      broadcast_note = create_broadcast_note(:notable_id => tracker.id)
      Sidekiq::Testing.inline! do
        stub_ticket_associates(related_ticket_ids, tracker) do
          put :spam, {:id => tracker.display_id }
          tracker.reload
          assert_tracker_spammed tracker, related_ticket_ids, broadcast_note.id        
        end
      end
    end
  end

  def test_delete_related
    enable_link_tickets do
      related_ticket_ids = create_link_tickets
      tracker = Helpdesk::Ticket.last
      ticket = Helpdesk::Ticket.find_by_display_id(related_ticket_ids.shift)
      Sidekiq::Testing.inline! do
        stub_ticket_associates(related_ticket_ids, tracker) do
          delete :destroy, {:id => ticket.display_id }
          ticket.reload
          assert_related_deleted(ticket)
        end
      end
    end
  end


  def test_spam_related
    enable_link_tickets do
      related_ticket_ids = create_link_tickets
      tracker = Helpdesk::Ticket.last
      ticket = Helpdesk::Ticket.find_by_display_id(related_ticket_ids.shift)
      Sidekiq::Testing.inline! do
        stub_ticket_associates(related_ticket_ids, tracker) do
          delete :destroy, {:id => ticket.display_id }
          ticket.reload
          assert_related_spammed(ticket)
        end
      end
    end
  end

  def test_fetch_related_tickets
    enable_link_tickets do
      related_ticket_ids = create_link_tickets
      tracker = Helpdesk::Ticket.last
      stub_ticket_associates(related_ticket_ids) do
        get :associated_tickets, {:id => tracker.display_id, :page => 1}
        related_ticket_ids.each {|id| assert_select "#related_ticket_list_item_#{id}"}
      end
    end
  end
end