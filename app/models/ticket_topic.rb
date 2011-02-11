class TicketTopic < ActiveRecord::Base
  belongs_to :topic, 
    :foreign_key => 'topic_id'
  
  belongs_to :ticket, 
    :class_name => 'Helpdesk::Ticket',
    :foreign_key => 'ticket_id'
    
   validates_uniqueness_of :topic_id,:ticket_id
  
end
