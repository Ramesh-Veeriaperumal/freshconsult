class CreateServiceApiKeys < ActiveRecord::Migration
  shard :none

  def up
    create_table :service_api_keys do |t|
      t.string :service_name,:null => false
      t.string :api_key,:null => false

      t.timestamps
    end
    add_index :service_api_keys, :service_name, :unique => true
    add_index :service_api_keys, :api_key, :unique => true
  end

  def down
  	drop_table :service_api_keys
  end
end
