module SharedOwnershipAssertions
  def assert_shared_ownership_tickets(tickets = [], internal_group_id, internal_agent_id)
    tickets.each do |ticket|
      assert_equal ticket.internal_group_id, internal_group_id, "Expected ticket internal group id => #{ticket.internal_group_id} is equal to assigned internal group id => #{internal_group_id}"
      assert_equal ticket.internal_agent_id, internal_agent_id, "Expected ticket internal agent id => #{ticket.internal_agent_id} is equal to assigned internal agent id => #{internal_agent_id}"
    end
  end

  def assert_tickets_status(tickets = [], status)
    tickets.each do |ticket|
      assert_equal ticket.status, status.status_id
    end
  end
end