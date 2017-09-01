class Freshcaller::Agent < ActiveRecord::Base
  self.table_name =  :freshcaller_agents
  self.primary_key = :id
  
  belongs_to_account
  belongs_to :agent
end
