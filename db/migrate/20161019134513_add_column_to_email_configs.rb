class AddColumnToEmailConfigs < ActiveRecord::Migration
  shard :all

  def self.up
    Lhm.change_table :email_configs, :atomic_switch => true do |m|
      m.add_column :outgoing_email_domain_category_id, "int(11) DEFAULT NULL"
    end
  end

  def self.down
    Lhm.change_table :email_configs, :atomic_switch => true do |m|
      m.remove_column :outgoing_email_domain_category_id
    end
  end
end
