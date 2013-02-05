class Helpdesk::Dropbox < ActiveRecord::Base

	set_table_name "helpdesk_dropboxes"

	belongs_to :droppable, :polymorphic => true

	belongs_to_account	
	
	before_save :set_account_id

	private

	def set_account_id
		self.account_id = droppable.account_id
	end
end