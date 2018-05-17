class AddLastErrorGitTagToSandboxJobs < ActiveRecord::Migration

  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :admin_sandbox_jobs, :atomic_switch => true do |m|
      m.add_column :last_error, "text DEFAULT NULL"
      m.add_column :git_tag, "varchar(255)"
    end
  end

  def down
    Lhm.change_table :admin_sandbox_jobs, :atomic_switch => true do |m|
      m.remove_column :last_error
      m.remove_column  :git_tag
    end
  end


end
