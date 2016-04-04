class CreateMonthlyStatsTables < ActiveRecord::Migration
  shard :none
  def self.up
  	for m in 1..12
  		table = 'ticket_stats_2013_'+m.to_s
  		execute("create table #{table} (account_id bigint(20) unsigned DEFAULT NULL,
  			ticket_id bigint(20) unsigned DEFAULT NULL,created_at datetime DEFAULT NULL,
  			created_hour int(11) unsigned DEFAULT NULL,resolved_hour int(11) unsigned DEFAULT NULL,
  			received_tickets int(11) unsigned NOT NULL DEFAULT '0',
  			resolved_tickets int(11) unsigned NOT NULL DEFAULT '0',
  			num_of_reopens int(11) unsigned NOT NULL DEFAULT '0',
  			assigned_tickets int(11) unsigned NOT NULL DEFAULT '0',
  			num_of_reassigns int(11) unsigned NOT NULL DEFAULT '0',
  			fcr_tickets int(11) unsigned NOT NULL DEFAULT '0',
  			sla_tickets int(11) unsigned NOT NULL DEFAULT '0',
  			UNIQUE  KEY index_ticket_stats_on_ticket_id_created_at_account_id (ticket_id, account_id, created_at),
  			KEY index_ticket_stats_on_account_id_created_at(account_id, created_at)) 
  			ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci 
  			PARTITION BY  HASH(account_id) PARTITIONS 128;") unless self.table_exists?(table)
  	end
  end

  def self.down
  	for m in 1..12
  		table = 'ticket_stats_2013_'+m.to_s
  		drop_table table
  	end
  end

  def self.table_exists?(table)
  	ActiveRecord::Base.connection.table_exists? table	
  end
end
