account = Account.current
ticket_field_id = account.ticket_fields.find_by_field_type("default_status") 

Helpdesk::TicketStatus.seed_many(:account_id, :status_id,[
  { :status_id => 2, :name => 'Open', :customer_display_name => 'Being Processed', :is_default => true, 
    :account => account, :ticket_field => ticket_field_id },
  { :status_id => 3, :name => 'Pending', :customer_display_name => 'Awaiting your Reply', :is_default => true,
    :account => account, :ticket_field => ticket_field_id },
  { :status_id => 4, :name => 'Resolved', :customer_display_name => 'This ticket has been Resolved', :stop_sla_timer => true, :is_default => true, 
    :account => account, :ticket_field => ticket_field_id },
  { :status_id => 5, :name => 'Closed', :customer_display_name => 'This ticket has been Closed', :stop_sla_timer => true, :is_default => true, 
    :account => account, :ticket_field => ticket_field_id },
  { :status_id => 6, :name => 'Waiting on Customer', :customer_display_name => 'Awaiting your Reply', :stop_sla_timer => true, 
    :account => account, :ticket_field => ticket_field_id },
  { :status_id => 7, :name => 'Waiting on Third Party', :customer_display_name => 'Being Processed', 
    :account => account, :ticket_field => ticket_field_id }]
)