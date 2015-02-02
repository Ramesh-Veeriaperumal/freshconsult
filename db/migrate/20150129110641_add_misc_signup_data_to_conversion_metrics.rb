class AddMiscSignupDataToConversionMetrics < ActiveRecord::Migration
  shard :all

  def self.up
    Lhm.change_table :conversion_metrics, :atomic_switch => true do |m|
      m.add_column :misc_signup_data, "text"
    end
  end

  def self.down
    Lhm.change_table :conversion_metrics, :atomic_switch => true do |m|
      m.remove_column :misc_signup_data
    end
  end
end
