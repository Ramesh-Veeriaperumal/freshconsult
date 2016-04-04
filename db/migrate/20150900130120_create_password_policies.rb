class CreatePasswordPolicies < ActiveRecord::Migration
  shard :all

  def change
    create_table :password_policies do |t|
      t.column :account_id, "bigint unsigned"
      t.integer :user_type,  null: false
      t.string :policies
      t.text :configs
      t.timestamps
    end

    add_index :password_policies, [:account_id, :user_type], :unique => true
  end
end
