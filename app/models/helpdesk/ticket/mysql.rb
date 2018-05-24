class Helpdesk::Ticket < ActiveRecord::Base
  
  def create_in_mysql
    # creating a new record
    ticket_old_body = self.build_ticket_old_body(construct_ticket_old_body_hash) 
    UnicodeSanitizer.encode_emoji(ticket_old_body, "description")
    ticket_old_body.save
  end

  def read_from_mysql
    return ticket_old_body
  end

  def update_in_mysql
    # case were a ticket without ticket_body is updated
    ticket_old_body = self.ticket_old_body || self.build_ticket_old_body 
    ticket_old_body.attributes = construct_ticket_old_body_hash
    UnicodeSanitizer.encode_emoji(ticket_old_body, "description")
    ticket_old_body.save
  end

  # dummy implementation
  def delete_in_mysql
  end

  alias_method :rollback_in_mysql, :delete_in_mysql
end
