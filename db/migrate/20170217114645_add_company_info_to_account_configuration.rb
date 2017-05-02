class AddCompanyInfoToAccountConfiguration < ActiveRecord::Migration
  shard :all

  def self.up
    Lhm.change_table :account_configurations, :atomic_switch => true do |m|
      m.add_column :company_info, :text
    end
  end

  def self.down
    Lhm.change_table :account_configurations, :atomic_switch => true do |m|
      m.remove_column :company_info
    end
  end

end
