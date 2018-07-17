class AddAdditionalDataToSandboxJobs < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :admin_sandbox_jobs, :atomic_switch => true do |m|
      m.add_column :additional_data, "mediumtext DEFAULT NULL"
    end
  end

  def down
    Lhm.change_table :admin_sandbox_jobs, :atomic_switch => true do |m|
      m.remove_column :additional_data
    end
  end
end
