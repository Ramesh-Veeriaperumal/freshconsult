class AddNameToFreshfoneNumbers < ActiveRecord::Migration
  shard :all
  def self.up
    Lhm.change_table :freshfone_numbers, :atomic_switch => true do |m|
      m.add_column :name, "varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL"
    end
  end

  def self.down
    Lhm.change_table :freshfone_numbers, :atomic_switch => true do |m|
      m.remove_column :name
    end
  end
end
