class AddTicketIdDelimiterToEmailCommandsSettings < ActiveRecord::Migration
	def self.up
		add_column :email_commands_settings, :ticket_id_delimiter, :string, :default => "#"
	end
	def self.down
		remove_column :email_commands_settings, :ticket_id_delimiter
	end
end
