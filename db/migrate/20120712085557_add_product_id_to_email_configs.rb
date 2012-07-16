class AddProductIdToEmailConfigs < ActiveRecord::Migration
  def self.up
		add_column :email_configs, :product_id, "bigint unsigned"

    add_index :email_configs, [:account_id, :product_id], :name => 'index_email_configs_on_account_id_and_product_id'

		execute("update email_configs set product_id = id where primary_role = 0")

		execute("update email_configs set primary_role = 1 where primary_role = 0")
  end

  def self.down
  	execute("update email_configs set primary_role = 0 where product_id is not NULL")
  	
  	remove_column :email_configs, :product_id
  end
end
