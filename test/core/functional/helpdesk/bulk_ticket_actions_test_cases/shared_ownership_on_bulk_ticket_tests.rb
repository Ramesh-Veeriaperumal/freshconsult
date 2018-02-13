module SharedOwnershipOnBulkTicketTests
  # Update the tickets created using one of the default status(like open), assign its status and internal group
  # and internal agent comes under that status. Check whether they get assigned or not.

  def test_assignment_of_internal_agent_and_group_with_custom_status
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_custom_internal_group
      ticket1 = create_ticket(status: 2)
      ticket2 = create_ticket(status: 2)
      Sidekiq::Testing.inline! do
        update_bulk_tickets([ticket1.display_id, ticket2.display_id],
                            internal_agent_id: @internal_agent.id,
                             internal_group_id: @internal_group.id,
                             status_id: @status.status_id})
      end

      ticket1.reload
      ticket2.reload

      assert_tickets_status [ticket1, ticket2], @status
      assert_shared_ownership_tickets [ticket1, ticket2], @internal_group.id, @internal_agent.id
    end
  end

  # Update bulk ticket created with the customized status by modifying its internal group
  # and internal agent, check whether they get assigned
  # under that status or not
  def test_assignment_of_internal_group_and_internal_agent_on_custom_status_ticket
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_custom_internal_group
      ticket1 = create_ticket(status: @status.status_id)
      ticket2 = create_ticket(status: @status.status_id)

      Sidekiq::Testing.inline! do
        put :update_multiple, ids: [ticket1.display_id, ticket2.display_id],
                               helpdesk_ticket: {
                                 internal_group_id: @internal_group.id,
                                 internal_agent_id: @internal_agent.id
                               },
                               helpdesk_note: { note_body_attributes: { body_html: '' },
                                                  private: '0',
                                                  user_id: @agent.id,
                                                  source: '0'}}
      end

      ticket1.reload
      ticket2.reload

      assert_shared_ownership_tickets [ticket1], @internal_group.id, @internal_agent.id
    end
  end

  def test_internal_agent_assignment_on_internal_group_ticket
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_custom_internal_group
      ticket1 = create_ticket({ status: @status.status_id, responder_id: @agent.id },
                              nil, @internal_group)
      ticket2 = create_ticket({ status: @status.status_id, responder_id: @agent.id },
                              nil, @internal_group)
      Sidekiq::Testing.inline! do
        put :update_multiple, ids: [ticket1.display_id, ticket2.display_id],
                               helpdesk_ticket: {
                                 internal_agent_id: @internal_agent.id
                               },
                               helpdesk_note: { note_body_attributes: { body_html: '' },
                                                  private: '0',
                                                  user_id: @agent.id,
                                                  source: '0'}}
      end

      ticket1.reload
      ticket2.reload

      assert_shared_ownership_tickets [ticket1, ticket2], @internal_group.id, @internal_agent.id
    end
  end

  def test_when_internal_agent_assigned_ticket_changed_to_default_status
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_custom_internal_group
      ticket1 = create_ticket({ status: @status.status_id, internal_agent_id: @internal_agent.id,
                               responder_id: @agent.id }, nil, @internal_group)
      ticket2 = create_ticket({ status: @status.status_id, internal_agent_id: @internal_agent.id,
                               responder_id: @agent.id }, nil, @internal_group)
      default_status = @account.ticket_statuses.first
      Sidekiq::Testing.inline! do
        put :update_multiple, ids: [ticket1.display_id, ticket2.display_id],
                               helpdesk_ticket: {
                                 status: default_status.status_id
                               },
                               helpdesk_note: { note_body_attributes: { body_html: '' },
                                                  private: '0',
                                                  user_id: @agent.id,
                                                  source: '0'}}
      end

      ticket1.reload
      ticket2.reload

      assert_shared_ownership_tickets [ticket1, ticket2], nil, nil
      assert_tickets_status [ticket1, ticket2], default_status
    end
  end

  def test_ticket_changed_to_custom_status_having_same_internal_group
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_custom_internal_group
      ticket1 = create_ticket({ status: @status.status_id, internal_agent_id: @internal_agent.id,
                               responder_id: @agent.id }, nil, @internal_group)
      ticket2 = create_ticket({ status: @status.status_id, internal_agent_id: @internal_agent.id,
                               responder_id: @agent.id }, nil, @internal_group)
      custom_status = @account.ticket_statuses.visible.where(is_default: 0).last
      custom_status.group_ids = [@internal_group.id]
      custom_status.save

      Sidekiq::Testing.inline! do
        put :update_multiple, ids: [ticket1.display_id, ticket2.display_id],
                               helpdesk_ticket: {
                                 status: custom_status.status_id
                               },
                               helpdesk_note: { note_body_attributes: { body_html: '' },
                                                  private: '0',
                                                  user_id: @agent.id,
                                                  source: '0'}}
      end

      ticket1.reload
      ticket2.reload

      assert_shared_ownership_tickets [ticket1, ticket2], @internal_group.id, @internal_agent.id
      assert_tickets_status [ticket1, ticket2], custom_status
    end
  end

  def test_ticket_changed_to_custom_status_having_different_internal_group
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_custom_internal_group
      ticket1 = create_ticket({ status: @status.status_id, internal_agent_id: @internal_agent.id,
                               responder_id: @agent.id }, nil, @internal_group)
      ticket2 = create_ticket({ status: @status.status_id, internal_agent_id: @internal_agent.id,
                               responder_id: @agent.id }, nil, @internal_group)
      new_internal_group = create_internal_group
      custom_status = @account.ticket_statuses.visible.where(is_default: 0).last
      custom_status.group_ids = [new_internal_group.id]
      custom_status.save
      Sidekiq::Testing.inline! do
        put :update_multiple, ids: [ticket1.display_id, ticket2.display_id],
                               helpdesk_ticket: {
                                 status: custom_status.status_id,
                                 internal_group_id: new_internal_group.id
                               },
                               helpdesk_note: { note_body_attributes: { body_html: '' },
                                                  private: '0',
                                                  user_id: @agent.id,
                                                  source: '0'}}
      end

      ticket1.reload
      ticket2.reload

      assert_shared_ownership_tickets [ticket1, ticket2], new_internal_group.id, nil
      assert_tickets_status [ticket1, ticket2], custom_status
    end
  end

  def test_ticket_changed_to_custom_status_having_different_internal_group_and_internal_agent
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_custom_internal_group
      ticket1 = create_ticket({ status: @status.status_id, internal_agent_id: @internal_agent.id,
                               responder_id: @agent.id }, nil, @internal_group)
      ticket2 = create_ticket({ status: @status.status_id, internal_agent_id: @internal_agent.id,
                               responder_id: @agent.id }, nil, @internal_group)
      new_internal_group = create_internal_group
      custom_status = @account.ticket_statuses.visible.where(is_default: 0).last
      custom_status.group_ids = [new_internal_group.id]
      custom_status.save
      new_internal_agent = add_agent_to_group(group_id = new_internal_group.id, ticket_permission = 3,
                                              role_id = @account.roles.first.id)
      Sidekiq::Testing.inline! do
        put :update_multiple, ids: [ticket1.display_id, ticket2.display_id],
                               helpdesk_ticket: {
                                 status: custom_status.status_id,
                                 internal_group_id: new_internal_group.id,
                                 internal_agent_id: new_internal_agent.id
                               },
                               helpdesk_note: { note_body_attributes: { body_html: '' },
                                                  private: '0',
                                                  user_id: @agent.id,
                                                  source: '0'}}
      end

      ticket1.reload
      ticket2.reload

      assert_shared_ownership_tickets [ticket1, ticket2], new_internal_group.id, new_internal_agent.id
      assert_tickets_status [ticket1, ticket2], custom_status
    end
  end

end
