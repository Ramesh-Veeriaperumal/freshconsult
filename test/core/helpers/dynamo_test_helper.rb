module DynamoTestHelper
  def stub_ticket_associates(child_ids, parent=nil, associates=nil)
    if parent
      associates ||= [parent.display_id]
      parent.stubs(:associates).returns(child_ids)
    else
      associates ||= child_ids
    end
    Helpdesk::Ticket.any_instance.stubs(:associates).returns(associates)
    Helpdesk::Ticket.any_instance.stubs(:associates=).returns(true)
    Helpdesk::Ticket.any_instance.stubs(:add_associates).returns(true)
    Helpdesk::Ticket.any_instance.stubs(:manual_publish_to_rmq).returns(true)
    if block_given?
      yield
      unstub_ticket_associates(parent)
    end
  end

  def unstub_ticket_associates(parent=nil)
    Helpdesk::Ticket.any_instance.unstub(:associates=)
    Helpdesk::Ticket.any_instance.unstub(:add_associates)
    Helpdesk::Ticket.any_instance.unstub(:manual_publish_to_rmq)
    Helpdesk::Ticket.any_instance.unstub(:associates)
    parent.unstub(:associates) if parent
  end

end