class AgentGroup < ActiveRecord::Base
  
 belongs_to :user
 belongs_to :group
 
 attr_protected  :group_id
  
end
