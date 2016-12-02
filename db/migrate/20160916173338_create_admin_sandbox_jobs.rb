class CreateAdminSandboxJobs < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    create_table :admin_sandbox_jobs do |t|
      t.column  :sandbox_account_id, "bigint unsigned"
      t.column  :initiated_by, "bigint unsigned"
      t.integer :status,  null: false
      t.column  :account_id, "bigint unsigned"

      t.timestamps
    end

    add_index :admin_sandbox_jobs, [:account_id]
  end

  def down
    drop_table :admin_sandbox_jobs
  end
end
