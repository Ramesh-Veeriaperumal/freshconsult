# frozen_string_literal: true

class Helpdesk::TicketBody < ActiveRecord::Base
  self.table_name = :helpdesk_ticket_bodies
  self.primary_key = :id

  belongs_to_account
  belongs_to :ticket, class_name: 'Helpdesk::Ticket', foreign_key: :ticket_id, inverse_of: :ticket_body
  attr_protected :account_id

  before_save :update_ticket_body_related_changes
  after_update ->(obj) { obj.ticket.update_timestamp }, :if => :changed?

  # Callbacks will be executed in the order in which they have been included.   
  # Included rabbitmq callbacks at the last 
  include RabbitMq::Publisher

  def update_ticket_body_related_changes
    @model_changes_present = changed?
    true
  end

  # Overriding publish_update_ticket_body_to_rabbitmq to check for changes
  def publish_update_ticket_body_to_rabbitmq
    if @model_changes_present
      publish_to_rabbitmq("ticket", "ticket_body", "update")
    end
  end

end