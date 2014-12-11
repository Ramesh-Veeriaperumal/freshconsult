class AddExecutedAtToHelpdeskTimeSheets < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_time_sheets, :executed_at, :datetime
  end

  def self.down
    remove_column :helpdesk_time_sheets, :executed_at
  end
end
