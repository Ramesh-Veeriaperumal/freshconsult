class Agent < ActiveRecord::Base
  
    
  belongs_to :user, :class_name =>'User', :foreign_key =>'user_id' , :dependent => :destroy 

  accepts_nested_attributes_for :user
  
  validates_presence_of :user_id
  
  attr_accessible :signature, :user_id , :ticket_permission, :occasional
  
  
  has_many :agent_groups ,:class_name => 'AgentGroup', :through => :user , :foreign_key =>'user_id', :source =>'agents'

  has_many :time_sheets , :class_name => 'Helpdesk::TimeSheet' , :through => :user , :foreign_key =>'user_id'

  before_create :set_default_ticket_permission
 
  TICKET_PERMISSION = [
    [ :all_tickets, 1 ], 
    [ :group_tickets,  2 ], 
    [ :assigned_tickets, 3 ]
  ]
 
  
  PERMISSION_TOKENS_BY_KEY = Hash[*TICKET_PERMISSION.map { |i| [i[1], i[0]] }.flatten]
  PERMISSION_KEYS_BY_TOKEN = Hash[*TICKET_PERMISSION.map { |i| [i[0], i[1]] }.flatten]
  
  def self.technician_list account_id
    
    agents = User.find(:all, :joins=>:agent, :conditions => {:account_id=>account_id, :deleted =>false} , :order => 'name')    
  
end

def all_ticket_permission
  ticket_permission == PERMISSION_KEYS_BY_TOKEN[:all_tickets]
end

def group_ticket_permission
  ticket_permission == PERMISSION_KEYS_BY_TOKEN[:group_tickets]
end

 def set_default_ticket_permission
   self.ticket_permission = PERMISSION_KEYS_BY_TOKEN[:all_tickets] if self.ticket_permission.blank?
 end


end
