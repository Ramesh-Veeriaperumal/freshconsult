class AddTicketDisplayIdToAccount < ActiveRecord::Migration
  def self.up
    add_column :accounts, :ticket_display_id, :integer , :default => 0
  end

  def self.down
    remove_column :accounts, :ticket_display_id
  end
end
