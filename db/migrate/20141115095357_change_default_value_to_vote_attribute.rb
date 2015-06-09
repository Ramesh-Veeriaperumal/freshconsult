class ChangeDefaultValueToVoteAttribute < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :votes, :atomic_switch => true do |m|
      m.change_column :vote, "tinyint DEFAULT '1'"
    end
  end

  def down
    Lhm.change_table :votes, :atomic_switch => true do |m|
      m.change_column :vote, "tinyint DEFAULT '0'"
    end
  end
end
