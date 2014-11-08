class AddNameToChatWidgets < ActiveRecord::Migration
  shard :all
  def self.up
	  execute <<-SQL
	      alter table chat_widgets add column name VARCHAR(255)
	  SQL

      execute <<-SQL
           update chat_widgets c set c.name = 
           (select case when c.main_widget = 'true' 
           	then 
              (select p.name from products p where p.account_id = c.account_id && c.product_id = p.id) 
            else 
               (select a.name from accounts a where a.id = c.account_id)
            end )
	  SQL
  end

  def self.down
      execute <<-SQL
         alter table chat_widgets drop column name 
      SQL
  end
end
