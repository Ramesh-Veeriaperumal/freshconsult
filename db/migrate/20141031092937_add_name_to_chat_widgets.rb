class AddNameToChatWidgets < ActiveRecord::Migration
  shard :all
  def self.up
	  execute <<-SQL
	   alter table chat_widgets add column name VARCHAR(255) DEFAULT NULL AFTER id
	  SQL

    execute <<-SQL
      alter table chat_widgets change column account_id account_id bigint(20) NOT NULL
    SQL

    execute <<-SQL
      update chat_widgets c inner join accounts a on c.account_id = a.id and c.main_widget = 1 set c.name = a.name
    SQL
    
    execute <<-SQL
      update chat_widgets c inner join products p on c.product_id = p.id and c.main_widget = 0 set c.name = p.name
    SQL
  end

  def self.down
      execute <<-SQL
         alter table chat_widgets drop column name 
      SQL
  end
end
