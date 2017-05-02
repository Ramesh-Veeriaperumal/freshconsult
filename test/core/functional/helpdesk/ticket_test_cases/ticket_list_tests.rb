module TicketListTests
  def test_tickets_shared_by_Internal_agent
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_default_internal_group

      ticket1 = create_ticket({:status => @status.status_id, :internal_agent_id => @internal_agent.id,
                               :responder_id => @responding_agent.id}, nil, @internal_group)
      ticket2 = create_ticket({:status => 2, :responder_id => @responding_agent.id})

      login_as(@responding_agent)

      get :index, :filter_name => "shared_by_me"

      assert_match /#{ticket1.subject}/, response.body
      assert_no_match /#{ticket2.subject}/, response.body
    end
  end

  def test_tickets_shared_with_Internal_agent
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_default_internal_group

      ticket1 = create_ticket({:status => @status.status_id, :internal_agent_id => @internal_agent.id,
                               :responder_id => @responding_agent.id}, nil, @internal_group)
      ticket2 = create_ticket({:status => 2, :responder_id => @internal_agent.id})

      login_as(@internal_agent)

      get :index, :filter_name => "shared_with_me"

      assert_match /#{ticket1.subject}/, response.body
      assert_no_match /#{ticket2.subject}/, response.body
    end
  end

  def test_filter_by_internal_agent_with_agent
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_default_internal_group

      ticket = create_ticket({:status => @status.status_id, :internal_agent_id => @internal_agent.id,
                               :responder_id => @responding_agent.id}, nil, @internal_group)


      condition = {"condition": "internal_agent_id", "operator": "is_in",
                   "ff_name": "default", "value": @internal_agent.id.to_s}
      custom_search_on_ticket_list_filters([condition], agent_mode = 1)

      assert_match /#{ticket.subject}/, response.body
    end
  end

  def test_filter_by_internal_group_with_group
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_default_internal_group

      ticket = create_ticket({:status => @status.status_id, :internal_agent_id => @internal_agent.id,
                               :responder_id => @responding_agent.id}, nil, @internal_group)


      condition = {"condition": "internal_group_id", "operator": "is_in",
                   "ff_name": "default", "value": @internal_group.id.to_s}
      custom_search_on_ticket_list_filters([condition], group_mode = 1)

      assert_match /#{ticket.subject}/, response.body
    end
  end

  def test_filter_by_any_agent_with_agent
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_default_internal_group

      ticket = create_ticket({:status => @status.status_id, :internal_agent_id => @internal_agent.id,
                              :responder_id => @responding_agent.id}, nil, @internal_group)

      condition = {"condition": "any_agent_id", "operator": "is_in",
                   "ff_name": "default", "value": @internal_agent.id.to_s}
      custom_search_on_ticket_list_filters([condition], agent_mode = 2)

      assert_match /#{ticket.subject}/, response.body
    end
  end

  def test_filter_by_any_group_with_group
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_default_internal_group

      ticket = create_ticket({:status => @status.status_id, :internal_agent_id => @internal_agent.id,
                              :responder_id => @responding_agent.id}, nil, @internal_group)

      condition = {"condition": "any_group_id", "operator": "is_in",
                   "ff_name": "default", "value": @internal_group.id.to_s}
      custom_search_on_ticket_list_filters([condition], group_mode = 2)

      assert_match /#{ticket.subject}/, response.body
    end
  end

  def test_filter_by_internal_agent_and_internal_group_with_agent_and_group
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_default_internal_group

      ticket1 = create_ticket({:status => @status.status_id, :internal_agent_id => @internal_agent.id,
                              :responder_id => @responding_agent.id}, nil, @internal_group)
      ticket2 = create_ticket({:status => 2, :responder_id => @internal_agent.id},group = @internal_group)

      agent_condition = {"condition": "internal_agent_id", "operator": "is_in",
                   "ff_name": "default", "value": @internal_agent.id.to_s}
      group_condition = {"condition": "internal_group_id", "operator": "is_in",
                         "ff_name": "default", "value": @internal_group.id.to_s}
      custom_search_on_ticket_list_filters([agent_condition, group_condition], agent_mode = 1, group_mode = 1)

      assert_match /#{ticket1.subject}/, response.body
      assert_no_match /#{ticket2.subject}/, response.body
    end
  end

  def test_filter_by_any_agent_and_any_group_with_agent_and_group
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_default_internal_group

      ticket1 = create_ticket({:status => @status.status_id, :internal_agent_id => @internal_agent.id,
                               :responder_id => @responding_agent.id}, nil, @internal_group)
      ticket2 = create_ticket({:status => 2, :responder_id => @internal_agent.id},group = @internal_group)

      agent_condition = {"condition": "any_agent_id", "operator": "is_in",
                         "ff_name": "default", "value": @internal_agent.id.to_s}
      group_condition = {"condition": "any_group_id", "operator": "is_in",
                         "ff_name": "default", "value": @internal_group.id.to_s}
      custom_search_on_ticket_list_filters([agent_condition, group_condition], agent_mode = 2, group_mode = 2)

      assert_match /#{ticket1.subject}/, response.body
      assert_match /#{ticket2.subject}/, response.body
    end
  end

  def test_filter_by_any_agent_and_any_group_with_agent
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_default_internal_group

      ticket1 = create_ticket({:status => @status.status_id, :internal_agent_id => @internal_agent.id,
                               :responder_id => @responding_agent.id}, nil, @internal_group)
      ticket2 = create_ticket({:status => 2, :responder_id => @responding_agent.id},group = @internal_group)

      agent_condition = {"condition": "any_agent_id", "operator": "is_in",
                         "ff_name": "default", "value": @internal_agent.id.to_s}
      custom_search_on_ticket_list_filters([agent_condition], agent_mode = 2, group_mode = 2)

      assert_match /#{ticket1.subject}/, response.body
      assert_no_match /#{ticket2.subject}/, response.body
    end
  end



end