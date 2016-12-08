module LinkTicketNegativeTests

  def test_tracker_create_with_no_related
    enable_link_tickets do
      stub_ticket_associates([]) do
        post :create, ticket_params_hash(:email => @agent.email, display_ids: "")
        ticket = Helpdesk::Ticket.last
        assert !ticket.tracker_ticket?
      end
    end
  end

  def test_link_to_normal_ticket
    create_ticket
    ticket1 = Helpdesk::Ticket.last
    create_ticket
    ticket2 = Helpdesk::Ticket.last
    enable_link_tickets do
      stub_ticket_associates([ticket2.display_id], ticket1) do
        put :link, {:id => ticket2.display_id, :tracker_id => ticket1.display_id}
        assert_equal I18n.t("ticket.link_tracker.permission_denied"), flash[:notice]
        assert_not_related ticket1,ticket2
      end
    end
  end


  def test_unlink_normal_ticket
    enable_link_tickets do
      related_ticket_ids = create_link_tickets
      tracker = Helpdesk::Ticket.last
      ticket = create_ticket
      Sidekiq::Testing.inline! do
        stub_ticket_associates(related_ticket_ids, tracker) do
          put :unlink, {:id => ticket.display_id, :tracker => false, :tracker_id => tracker.display_id}
          assert_response :redirect
          assert !ticket.related_ticket?
        end
      end
    end
  end

  def test_fetch_related_tickets_from_related
    enable_link_tickets do
      related_ticket_ids = create_link_tickets
      related_id = related_ticket_ids.shift
      stub_ticket_associates(related_ticket_ids) do
        get :associated_tickets, {:id => related_id, :page => 1}
        assert_response :success
        assert_blank @response.body
      end
    end
  end

  def test_linking_to_tracker_with_maximum_related_tickets
    enable_link_tickets do
      related_ticket_ids = create_link_tickets(TicketConstants::MAX_RELATED_TICKETS)
      tracker = Helpdesk::Ticket.last
      create_ticket
      ticket = Helpdesk::Ticket.last
      stub_ticket_associates(related_ticket_ids << ticket.display_id) do
        put :link, {:id => ticket.display_id, :tracker_id => tracker.display_id}
        assert_equal I18n.t("ticket.link_tracker.count_exceeded", :count => TicketConstants::MAX_RELATED_TICKETS), flash[:notice]
        assert_not_related tracker, ticket
      end
    end
  end

  def test_multiple_linking_to_tracker_with_maximum_related_tickets
    enable_link_tickets do
      related_ticket_ids = create_link_tickets(TicketConstants::MAX_RELATED_TICKETS - 2 )
      tracker = Helpdesk::Ticket.last
      tickets_to_link = 5.times.collect {create_ticket.display_id}
      ticket = Helpdesk::Ticket.last
      stub_ticket_associates(related_ticket_ids) do
        put :link, {:id => "multiple", :ids => tickets_to_link, :tracker_id => tracker.display_id}
        assert_equal I18n.t("ticket.link_tracker.remaining_count", :count => 2), flash[:notice]
        tickets_to_link.each {|id| assert_not_related tracker, Helpdesk::Ticket.find_by_display_id(id)}
      end
    end
  end
end