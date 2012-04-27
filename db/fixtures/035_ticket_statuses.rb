account = Account.current

Helpdesk::TicketStatus.seed_many(:account_id, :status_id,[
  { :status_id => 2, :name => 'Open', :customer_display_name => 'Open', :is_default => true, :account => account,
    :ticket_field => account.ticket_fields.find_by_field_type("default_status")},
  { :status_id => 3, :name => 'Pending', :customer_display_name => 'Pending', :is_default => true,
    :account => account, :ticket_field => account.ticket_fields.find_by_field_type("default_status") },
  { :status_id => 4, :name => 'Resolved', :customer_display_name => 'Resolved', :stop_sla_timer => true, :is_default => true, 
    :account => account, :ticket_field => account.ticket_fields.find_by_field_type("default_status") },
  { :status_id => 5, :name => 'Closed', :customer_display_name => 'Closed', :stop_sla_timer => true, :is_default => true, 
    :account => account, :ticket_field => account.ticket_fields.find_by_field_type("default_status") }]
)