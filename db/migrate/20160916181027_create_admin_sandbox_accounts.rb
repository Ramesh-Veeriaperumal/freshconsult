class CreateAdminSandboxAccounts < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    create_table :admin_sandbox_accounts do |t|
      t.column  :account_id, "bigint unsigned"
      t.column  :sandbox_account_id, "bigint unsigned"
      t.integer :status,  :default => 0
      t.string  :config
      t.string  :git_tag
      t.timestamps
    end

    add_index :admin_sandbox_accounts, [:account_id]
  end

  def down
    drop_table :admin_sandbox_accounts
  end  
end
