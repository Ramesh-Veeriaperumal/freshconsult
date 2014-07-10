class AddNonBusinessHoursMessageToFreshfoneNumbers < ActiveRecord::Migration
  shard :none
  def self.up
    Lhm.change_table :freshfone_numbers, :atomic_switch => true do |m|
      m.add_column :non_business_hours_message, :text
    end
  end

  def self.down
    Lhm.change_table :freshfone_numbers, :atomic_switch => true do |m|
      m.remove_column :freshfone_numbers, :non_business_hours_message
    end
  end
end
