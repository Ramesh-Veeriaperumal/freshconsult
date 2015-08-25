class AddConferenceToFreshfoneCalls < ActiveRecord::Migration
  shard :none
  def self.up
    Lhm.change_table :freshfone_calls, :atomic_switch => true do |m|
      m.add_column :conference_sid, "varchar(50)"
    end
  end

  def self.down
    Lhm.change_table :freshfone_calls, :atomic_switch => true do |m|
      remove_column :conference_sid
    end
  end
end
