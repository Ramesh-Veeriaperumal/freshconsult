class CreateAdminUsers < ActiveRecord::Migration
	shard :shard_1
  def self.up
  	create_table :admin_users do |t|
      t.string :name, :password_salt, :crypted_password, :email, :perishable_token, :persistence_token
      t.integer :role
      t.boolean :active, :default => false
      t.datetime :last_request_at
      t.timestamps
    end
  end

  def self.down
  	drop_table :admin_users
  end
end
