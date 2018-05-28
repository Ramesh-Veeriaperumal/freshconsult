class UpdateColumnsInFailedCentralFeeds < ActiveRecord::Migration
  shard :none

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :failed_central_feeds, :atomic_switch => true do |t|
      t.change :exception, :text
      t.add_column :worker_name, "varchar(255)"
    end
  end

  def down
    Lhm.change_table :failed_central_feeds, :atomic_switch => true do |t|
      t.change :exception, :string, limit: 255
      t.remove_column :worker_name
    end
  end
end