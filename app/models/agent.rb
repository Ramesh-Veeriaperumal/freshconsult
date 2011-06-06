class Agent < ActiveRecord::Base
  
    
  belongs_to :user, :class_name =>'User', :foreign_key =>'user_id' , :dependent => :destroy 

  accepts_nested_attributes_for :user
  
  validates_presence_of :user_id
  
  attr_accessible :signature, :user_id
  
  has_many :agent_groups ,:class_name => 'AgentGroup', :through => :user , :foreign_key =>'user_id', :source =>'agents'
  
  def self.technician_list account_id
    
    agents = User.find(:all, :joins=>:agent, :conditions => {:account_id=>account_id, :deleted =>false} , :order => 'name')    
  
  end

end
