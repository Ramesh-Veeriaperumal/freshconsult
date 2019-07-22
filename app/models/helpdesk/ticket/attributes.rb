class Helpdesk::Ticket < ActiveRecord::Base
  attr_accessor :ticket_body_content, :rollback_ticket_body, :previous_value

  # This method is defined only for alias method chaining
  def description
    self.read_attribute(:description)
  end

  # This method is defined only for alias method chaining
  def description_html
    self.read_attribute(:description_html)
  end

  # construction of ticket_body based on params returns a Helpdesk::TicketBody object
  # this also gets called when build_ticket_body is called on Helpdesk::Ticket object
  def ticket_body_attributes=(options={})
    if self.ticket_body_content && (self.ticket_body_content.class == Helpdesk::TicketBody)
      self.previous_value = self.ticket_body_content
    end
    self.ticket_body_content = Helpdesk::TicketBody.new(options)
    self.ticket_body_content.description_html_changed = true
    self.ticket_body_content
  end

  def reopened_flag
    reopened_now?
  end

  def resolved_flag
    resolved_now?
  end

  # ticket_body association between Helpdesk::Ticket and Helpdesk::TicketBody
  # has_one relationship is not defined
  # this method takes care of the association
  def ticket_body
    self.ticket_body_content ||= fetch
  end

  # returns ticket_bodies description
  def description_with_ticket_body
    (ticket_body && ticket_body.description) ? ticket_body.description : read_attribute(:description)
  end

  # returns ticket_bodies description_html
  def description_html_with_ticket_body
    (ticket_body && ticket_body.description_html) ? ticket_body.description_html : read_attribute(:description_html)
  end

  # When ever build_ticket_body on Helpdesk::Ticket object is called
  # :ticket_body_attributes= gets called
  alias_method :build_ticket_body, :ticket_body_attributes=

  # when ever Helpdesk::Ticket.new.description method is called
  # it calls description_with_ticket_body
  alias_method_chain :description, :ticket_body

  # when ever Helpdesk::Ticket.new.description_html method is called
  # it calls description_html_with_ticket_body
  alias_method_chain :description_html, :ticket_body

  # Return a Helpdesk::TicketBody object if it is present in riak
  # Returns a Helpdesk::TicketOldBody object from mysql  if the element is not found in riak
  # Returns a empty Helpdesk::TicketBody if it is not present in riak as well as in mysql
  def fetch
    begin
    # in case of new record return new object
      return Helpdesk::TicketBody.new unless self.id
      ticket_body = safe_send("read_from_#{$primary_cluster}") 
      if ticket_body
        return ticket_body
      else
        safe_send("read_from_#{$secondary_cluster}") 
      end
    rescue Exception => e
      safe_send("read_from_#{$secondary_cluster}") 
    end
  end
  
  # the following code will get executed only in development 
  # no operation 
  def no_op
  end

  alias_method :read_from_none, :no_op
  alias_method :create_in_none, :no_op
  alias_method :update_in_none, :no_op
  alias_method :delete_in_none, :no_op
  alias_method :rollback_in_none, :no_op
  alias_method :load_full_text, :no_op
end
