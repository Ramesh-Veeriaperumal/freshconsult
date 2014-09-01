class TicketTopic < ActiveRecord::Base
  belongs_to :topic, 
    :foreign_key => 'topic_id'
  
  belongs_to :ticket, 
    :class_name => 'Helpdesk::Ticket',
    :foreign_key => 'ticket_id'
  
  belongs_to_account  
      
  validates_uniqueness_of :topic_id,:ticket_id
   
   
  validates_presence_of :topic_id,:ticket_id

  before_create :set_account_id

  private
    def set_account_id
      self.account_id = ticket.account_id
    end
  
end
