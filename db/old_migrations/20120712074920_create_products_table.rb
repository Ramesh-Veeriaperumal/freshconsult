class CreateProductsTable < ActiveRecord::Migration
  def self.up
		create_table(:products, :options => 'ENGINE=InnoDB AUTO_INCREMENT=15000 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci') do |t|
      t.string :name
      t.text :description
      t.column :account_id, "bigint unsigned"

      t.timestamps
    end

    add_index :products, [:account_id, :name], :name => 'index_products_on_account_id_and_name'

    execute("insert into products(id,name,created_at,updated_at)  select id, name, created_at, updated_at from email_configs where primary_role = 0")
  end

  def self.down
  	drop_table :products
  end
end
