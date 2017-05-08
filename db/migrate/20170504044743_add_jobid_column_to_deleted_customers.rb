class AddJobidColumnToDeletedCustomers < ActiveRecord::Migration
	shard :all
  def migrate(direction)
    self.send(direction)
  end

  def up
  	Lhm.change_table :deleted_customers, :atomic_switch => true do |m|
      m.add_column :job_id, :text
    end
  end

  def down
  	Lhm.change_table :deleted_customers, :atomic_switch => true do |m|
      m.remove_column :job_id
    end
  end
end
