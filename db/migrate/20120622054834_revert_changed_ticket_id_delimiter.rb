class RevertChangedTicketIdDelimiter < ActiveRecord::Migration
  def self.up
  	change_column :email_commands_settings, :ticket_id_delimiter, :string, :default => "#"
  	execute("update email_commands_settings set ticket_id_delimiter='#'")
  end

  def self.down
  end
end
