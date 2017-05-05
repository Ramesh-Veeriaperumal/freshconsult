module TicketDetailsTests

  # Test when group restricted agent trying to access the ticket which has been assigned to its group
  def test_ticket_access_by_assigned_group_agent
    group = @account.groups.first
    ticket = create_ticket({:status => 2}, group)
    group_restricted_agent = add_agent_to_group(group_id = group.id,
                                                ticket_permission = 2, role_id = @account.roles.agent.first.id)
    login_as(group_restricted_agent)
    get :show, :id => ticket.display_id

    assert_match /#{ticket.description_html}/, response.body
  end


  # Test access of ticket by ticket restricted agent who can view only those tickets which has been assigned to him
  def test_tickets_access_by_assigned_agent
    ticket_restricted_agent = add_agent_to_group(nil,
                                                 ticket_permission = 3, role_id = @account.roles.agent.first.id)
    ticket = create_ticket({:status => 2, :responder_id => ticket_restricted_agent.id})
    login_as(ticket_restricted_agent)
    get :show, :id => ticket.display_id

    assert_match /#{ticket.description_html}/, response.body
  end

  # Test when Internal agent have group tickets access.
  def test_access_for_group_restricted_agent
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_default_internal_group

      group_restricted_agent = add_agent_to_group(group_id = @internal_group.id,
                                                  ticket_permission = 2, role_id = @account.roles.first.id)
      ticket = create_ticket({:status => @status.status_id}, nil, @internal_group)
      login_as(group_restricted_agent)
      get :show, :id => ticket.display_id
      assert_match /#{ticket.description_html}/, response.body
    end
  end

  # Test ticket access by Internal agent when ticket has been assigned to him
  def test_ticket_access_by_Internal_restricted_agent
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_default_internal_group

      ticket = create_ticket({:status => @status.status_id, :internal_agent_id => @internal_agent.id}, nil, @internal_group)
      login_as(@internal_agent)
      get :show, :id => ticket.display_id
      assert_match /#{ticket.description_html}/, response.body
    end
  end

  def test_ticket_assignment_to_internal_agent
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_default_internal_group

      ticket = create_ticket({:status => 2, :responder_id => @responding_agent.id}, group = @account.groups.find_by_id(2))
      put :update, { :id => ticket.display_id,
                     :helpdesk_ticket => {
                       :status => @status.status_id,
                       :internal_group_id => @internal_group.id,
                       :internal_agent_id => @internal_agent.id
                     }
      }
      ticket.reload
      login_as(@internal_agent)
      get :show, :id => ticket.display_id
      assert_match /#{ticket.description_html}/, response.body
    end
  end

end