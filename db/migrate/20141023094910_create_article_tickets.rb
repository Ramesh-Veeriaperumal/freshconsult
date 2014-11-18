class CreateArticleTickets < ActiveRecord::Migration

	shard :all

	def self.up
		create_table :article_tickets, :id => false do |t|
			t.integer 	:article_id, :limit => 8
			t.integer 	:ticket_id, :limit => 8
			t.integer 	:account_id, :limit => 8
		end
		add_index :article_tickets, :account_id
		add_index :article_tickets, :article_id

		# Query that could be used:
		# SELECT `helpdesk_tickets`.* FROM `helpdesk_tickets` 
		# INNER JOIN `article_tickets` ON `helpdesk_tickets`.id = `article_tickets`.ticket_id 
		# WHERE ((`article_tickets`.article_id = 8)) AND (`helpdesk_tickets`.`account_id` = 1) 
		# In the articles table we are querying through article_id NOT IN conjuction with account_id

	end

	def self.down
		drop_table :article_tickets
	end
end
