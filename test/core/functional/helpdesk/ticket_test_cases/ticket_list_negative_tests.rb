module TicketListNegativeTests
  def test_filter_by_internal_agent
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_default_internal_group

      ticket = create_ticket({:status => @status.status_id, :internal_agent_id => @internal_agent.id,
                               :responder_id => @responding_agent.id}, nil, @internal_group)

      custom_search_on_ticket_list_filters([], agent_mode = 1)

      assert_match /#{ticket.subject}/, response.body
    end
  end

  def test_filter_by_internal_group
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_default_internal_group

      ticket = create_ticket({:status => @status.status_id, :internal_agent_id => @internal_agent.id,
                               :responder_id => @responding_agent.id}, nil, @internal_group)

      custom_search_on_ticket_list_filters([], group_mode = 1)

      assert_match /#{ticket.subject}/, response.body
    end
  end

  def test_filter_by_any_agent
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_default_internal_group

      ticket = create_ticket({:status => 2, :responder_id => @internal_agent.id},group = @internal_group)

      custom_search_on_ticket_list_filters([], agent_mode = 2)

      assert_match /#{ticket.subject}/, response.body
    end
  end

  def test_filter_by_any_group
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_default_internal_group

      ticket = create_ticket({:status => 2, :responder_id => @internal_agent.id},group = @internal_group)

      custom_search_on_ticket_list_filters([], group_mode = 2)

      assert_match /#{ticket.subject}/, response.body
    end
  end

  def test_flter_by_internal_group_and_internal_agent
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_default_internal_group

      ticket = create_ticket({:status => @status.status_id, :internal_agent_id => @internal_agent.id,
                               :responder_id => @responding_agent.id}, nil, @internal_group)

      custom_search_on_ticket_list_filters([], agent_mode = 1, group_mode = 1)

      assert_match /#{ticket.subject}/, response.body
    end
  end

  def test_filter_by_any_agent_and_any_group
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_default_internal_group

      ticket = create_ticket({:status => 2, :responder_id => @internal_agent.id},group = @internal_group)


      custom_search_on_ticket_list_filters([], agent_mode = 2, group_mode = 2)

      assert_match /#{ticket.subject}/, response.body
    end
  end

end