class CustomTranslation < ActiveRecord::Base
	self.primary_key = :id
	self.table_name = "custom_translations"
	serialize :translations, Hash
	belongs_to :translatable, :polymorphic => true
	belongs_to_account
	scope :only_ticket_fields, { :conditions => ["translatable_type = ?", "Helpdesk::TicketField"] }
end