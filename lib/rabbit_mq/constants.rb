module RabbitMq::Constants

  ACTION = { 
    :new            => "new_ticket", 
    :status_update  => "status_update", 
    :user_assign    => "assign_me", 
    :group_assign   => "assign_group", 
    :agent_reply    => "agent_reply", 
    :customer_reply => "customer_reply"
  }

end