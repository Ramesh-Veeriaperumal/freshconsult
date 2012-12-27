class ChangeCannedResponseUserAccesses < ActiveRecord::Migration
  def self.up
  	execute("update admin_user_accesses set accessible_type='Admin::CannedResponses::Response' where accessible_type='Admin::CannedResponse'")
  end

  def self.down
  end
end
