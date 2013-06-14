class AgentGroup < ActiveRecord::Base
 
	belongs_to_account
	belongs_to :user
	belongs_to :group

	validates_presence_of :user_id
end