class TicketTopic < ActiveRecord::Base
  self.primary_key = :id
  belongs_to :topic, 
    :foreign_key => 'topic_id'
  
  belongs_to :ticketable, :polymorphic => true

  belongs_to_account  
      
  validates_presence_of :topic_id,:ticketable_id,:ticketable_type

  before_create :set_account_id
 
  alias_method :ticket, :ticketable

  private
    
  def set_account_id
    self.account_id = ticket.account_id unless account_id
  end
  
end
