class AddAdditionalInfoToSubscriptions < ActiveRecord::Migration
  shard :all
  def self.up
    Lhm.change_table :subscriptions, :atomic_switch => true do |m|
      m.add_column :additional_info, 'text DEFAULT NULL'
    end
  end

  def self.down
    Lhm.change_table :subscriptions, :atomic_switch => true do |m|
      m.remove_column :additional_info
    end
  end
end
