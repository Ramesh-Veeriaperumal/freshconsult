class AddAccountIdToTicketTopics < ActiveRecord::Migration
  def self.up
  	add_column :ticket_topics, :account_id, "bigint unsigned"
  end

  def self.down
  	remove_column :ticket_topics, :account_id
  end
end
