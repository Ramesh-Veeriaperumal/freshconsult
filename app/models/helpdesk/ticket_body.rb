# frozen_string_literal: true

class Helpdesk::TicketBody < ActiveRecord::Base
  self.table_name = :helpdesk_ticket_bodies
  self.primary_key = :id

  belongs_to_account
  belongs_to :ticket, class_name: 'Helpdesk::Ticket', foreign_key: :ticket_id, inverse_of: :ticket_body
  attr_protected :account_id

  after_update ->(obj) { obj.ticket.update_timestamp }, :if => :changed?

  # Callbacks will be executed in the order in which they have been included.   
  # Included rabbitmq callbacks at the last 
  include RabbitMq::Publisher

end