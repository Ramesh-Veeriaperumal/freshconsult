class ChangeTicketIdDelmiter < ActiveRecord::Migration
  def self.up
  	change_column :email_commands_settings, :ticket_id_delimiter, :string, :default => "[#ticket_id]"
  	execute("update email_commands_settings set ticket_id_delimiter='[#ticket_id]' where ticket_id_delimiter = '#'")
  	execute("update email_commands_settings set ticket_id_delimiter='[##ticket_id]' where ticket_id_delimiter = '##'")
  end

  def self.down
  	change_column :email_commands_settings, :ticket_id_delimiter, :string, :default => "#"
  	execute("update email_commands_settings set ticket_id_delimiter='#' where ticket_id_delimiter = '[#ticket_id]'")
  	execute("update email_commands_settings set ticket_id_delimiter='##' where ticket_id_delimiter = '[##ticket_id]'")
  end
end
