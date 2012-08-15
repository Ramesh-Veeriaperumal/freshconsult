class PopulateSchemaLessNotes < ActiveRecord::Migration
  def self.up
  	Account.find(:all, :order => "accounts.id").each do |account|
		execute("insert ignore into helpdesk_schema_less_notes(note_id, account_id, created_at, updated_at)
				 select id, account_id, now(), now() from helpdesk_notes where account_id=#{account.id}")
	end
  end

  def self.down
  end
end
