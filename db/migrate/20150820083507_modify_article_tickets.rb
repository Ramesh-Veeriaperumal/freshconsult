class ModifyArticleTickets < ActiveRecord::Migration
  shard :all
  def up
  	Lhm.change_table :article_tickets, :atomic_switch => true do |m|
      m.add_column :ticketable_id ,  'bigint(20) unsigned DEFAULT NULL'
      m.add_column :ticketable_type ,  'varchar(255) DEFAULT NULL'
      m.add_index [:account_id,:ticketable_id, :ticketable_type], "index_ticket_topics_on_account_id_and_ticketetable"
    end
  end

  def down
  	Lhm.change_table :article_tickets, :atomic_switch => true do |m|
      m.remove_index [:account_id,:ticketable_id, :ticketable_type], "index_ticket_topics_on_account_id_and_ticketetable"
      m.remove_column :ticketable_id
      m.remove_column :ticketable_type
    end
  end
end