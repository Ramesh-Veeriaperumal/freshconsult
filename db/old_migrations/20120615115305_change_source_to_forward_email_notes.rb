class ChangeSourceToForwardEmailNotes < ActiveRecord::Migration
  def self.up
  	execute("update helpdesk_notes set source = 8 where source = 0 and private = 1 and incoming = 0 and deleted = 0 and created_at > '2012-05-27 00:00:00' ")
  end

  def self.down
  	execute("update helpdesk_notes set source = 0 where source = 8 and private = 1 and incoming = 0 and deleted = 0 and created_at > '2012-05-27 00:00:00' ")
  end
end
