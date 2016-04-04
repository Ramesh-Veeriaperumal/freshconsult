class AddAccountIdToHelpdeskTagUses < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_tag_uses, :account_id, "bigint unsigned"
  end

  def self.down
    remove_column :helpdesk_tag_uses, :account_id
  end
end
