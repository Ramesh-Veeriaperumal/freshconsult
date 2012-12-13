class AgentGroup < ActiveRecord::Base
 
 belongs_to_account
 belongs_to :user
 belongs_to :group
 
 validates_presence_of :user_id
 before_create :set_account_id

private
	def set_account_id
		self.account_id = user.account_id
	end

end
