class AddDeletedColumnToSurveys < ActiveRecord::Migration
  shard :all
  def self.up
    Lhm.change_table :surveys, :atomic_switch => true do |m|
      m.add_column :deleted, 'tinyint(1) DEFAULT 0'
    end
  end

  def self.down
    Lhm.change_table :surveys, :atomic_switch => true do |m|
      m.remove_column :deleted
    end
  end
end