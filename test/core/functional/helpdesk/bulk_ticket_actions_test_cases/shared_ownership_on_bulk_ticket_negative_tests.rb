module SharedOwnershipOnBulkTicketNegativeTests


  # Test the case when an internal agent is trying to access the ticket from
  # another internal group which he has not been assigned.
  def test_inter_group_ticket_access
    enable_feature(:shared_ownership) do
      internal_group = create_internal_group
      status = @account.ticket_statuses.where(:is_default => 0).first
      status.group_ids = [internal_group.id]
      status.save
      @account.instance_variable_set(:@account_status_groups_from_cache, nil)

      internal_agent = add_agent_to_group(group_id = nil, ticket_permission = 2,
                                          role_id = @account.roles.first.id)
      test_ticket1 = create_ticket({ :status => status.status_id})
      test_ticket2 = create_ticket({ :status => status.status_id})
      @request.env['HTTP_REFERER'] = 'sessions/new'
      Sidekiq::Testing.inline! do
        update_bulk_tickets([test_ticket1.display_id, test_ticket2.display_id],
                            {:internal_agent_id => internal_agent.id,
                             :internal_group_id => internal_group.id,
                             :status_id => status.status_id
                            })
      end
      test_ticket1.reload
      test_ticket2.reload

      assert_shared_ownership_tickets [test_ticket1, test_ticket2], internal_group.id, nil
    end
  end


  # All internal group are mapped to some status. So assigning the internal agent and group to the ticket
  # should not be done on default status
  def test_assignment_of_agent_and_group_on_default_status
    enable_feature(:shared_ownership) do
      internal_group = create_internal_group
      internal_agent = add_agent_to_group(group_id = nil, ticket_permission = 2,
                                          role_id = @account.roles.first.id)
      test_ticket1 = create_ticket({ :status => 2})
      test_ticket2 = create_ticket({ :status => 2})
      @request.env['HTTP_REFERER'] = 'sessions/new'
      Sidekiq::Testing.inline! do
        update_bulk_tickets([test_ticket1.display_id, test_ticket2.display_id],
                            {:internal_agent_id => internal_agent.id,
                             :internal_group_id => internal_group.id,
                            })
      end

      test_ticket1.reload
      test_ticket2.reload

      assert_shared_ownership_tickets [test_ticket1, test_ticket2], nil, nil
    end
  end

  # Test the scenario when there is no group map to the status and we try to assign that group with the same status.

  def test_group_assignment_not_mapped_to_current_status
    enable_feature(:shared_ownership) do
      internal_group1 = create_internal_group
      status = @account.ticket_statuses.where(:is_default => 0).first
      status.group_ids = [internal_group1.id]
      status.save
      @account.instance_variable_set(:@account_status_groups_from_cache, nil)

      test_ticket1 = create_ticket({ :status => status.status_id})
      test_ticket2 = create_ticket({ :status => status.status_id})

      internal_group2 = create_internal_group
      internal_agent = add_agent_to_group(group_id = internal_group2, ticket_permission = 2,
                                          role_id = @account.roles.first.id)
      @request.env['HTTP_REFERER'] = 'sessions/new'
      Sidekiq::Testing.inline! do
        update_bulk_tickets([test_ticket1.display_id, test_ticket2.display_id],
                            {:internal_agent_id => internal_agent.id,
                             :internal_group_id => internal_group2.id,
                             :status_id => status.status_id
                            })
      end

      test_ticket1.reload
      test_ticket2.reload

      assert_shared_ownership_tickets [test_ticket1, test_ticket2], nil, nil
    end
  end

  def test_when_internal_agent_does_not_belongs_to_internal_group
    enable_feature(:shared_ownership) do
      internal_group = create_internal_group
      status = @account.ticket_statuses.where(:is_default => 0).first
      status.group_ids = [internal_group.id]
      status.save
      @account.instance_variable_set(:@account_status_groups_from_cache, nil)

      internal_agent = add_agent_to_group(group_id = nil, ticket_permission = 2,
                                          role_id = @account.roles.first.id)
      test_ticket1 = create_ticket({ :status => status.status_id})
      test_ticket2 = create_ticket({ :status => status.status_id})

      @request.env['HTTP_REFERER'] = 'sessions/new'
      Sidekiq::Testing.inline! do
        update_bulk_tickets([test_ticket1.display_id, test_ticket2.display_id],
                            {:internal_agent_id => internal_agent.id,
                             :internal_group_id => internal_group.id,
                             :status_id => status.status_id
                            })
      end

      test_ticket1.reload
      test_ticket2.reload

      assert_shared_ownership_tickets [test_ticket1, test_ticket2], internal_group_id = internal_group.id, nil
    end
  end

end