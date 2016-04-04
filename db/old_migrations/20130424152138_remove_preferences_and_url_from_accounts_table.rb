class RemovePreferencesAndUrlFromAccountsTable < ActiveRecord::Migration
  shard :none
  def self.up
  	Lhm.change_table :accounts, :atomic_switch => true do |m|
       m.ddl("ALTER TABLE %s DROP COLUMN helpdesk_url, DROP COLUMN preferences, DROP INDEX index_accounts_on_helpdesk_url" % m.name)
    end
  end

  def self.down
  	Lhm.change_table :accounts, :atomic_switch => true do |m|
       m.ddl %("ALTER TABLE %s ADD COLUMN helpdesk_url varchar(255) COLLATE utf8_unicode_ci 
        DEFAULT NULL, ADD COLUMN preferences text COLLATE utf8_unicode_ci, add index index_accounts_on_helpdesk_url (helpdesk_url)" % m.name")
    end
  end
end
