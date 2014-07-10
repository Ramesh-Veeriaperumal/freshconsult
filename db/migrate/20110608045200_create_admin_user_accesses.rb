class CreateAdminUserAccesses < ActiveRecord::Migration
  def self.up
    create_table :admin_user_accesses do |t|
      t.string  :accessible_type
      t.integer :accessible_id
      t.integer :user_id , :limit => 8
      t.integer :visibility, :limit => 8
      t.integer :group_id ,:limit => 8
      t.integer :account_id, :limit => 8

      t.timestamps
    end
    
    add_index :admin_user_accesses, [:account_id, :created_at], :name => 'index_admin_user_accesses_on_account_id_and_created_at'
    add_index :admin_user_accesses, [:user_id], :name => 'index_admin_user_accesses_on_user_id'
  end

  def self.down
    drop_table :admin_user_accesses
  end
end
