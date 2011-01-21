class Agent < ActiveRecord::Base
  
  belongs_to :user, :class_name =>'User', :foreign_key =>'user_id'
  
  accepts_nested_attributes_for :user
  
  validates_presence_of :user_id
  
  has_many :agent_groups ,:class_name => 'AgentGroup', :through => :user , :foreign_key =>'user_id', :source =>'agents'

end
