class Helpdesk::SchemaLessTicket < ActiveRecord::Base
  
  set_table_name "helpdesk_schema_less_tickets"

  belongs_to :helpdesk_ticket 

  belongs_to :product

  belongs_to_account

  attr_protected :account_id

  serialize :to_emails

end