class AddUniqueIndexImportIdAccountId < ActiveRecord::Migration
  def self.up
#    add_index :helpdesk_tickets, [:account_id, :import_id], :name => 'index_helpdesk_tickets_on_account_id_and_import_id', :unique => true
#    add_index :users, [:account_id, :import_id], :name => 'index_users_on_account_id_and_import_id', :unique => true
  end

  def self.down
#    remove_index :helpdesk_tickets, [:account_id, :import_id]
#    remove_index :users, [:account_id, :import_id]
  end
end
