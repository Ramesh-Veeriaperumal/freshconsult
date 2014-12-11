class AddCustomSslColumnsToPortals < ActiveRecord::Migration
  shard :none
  def self.up
  	Lhm.change_table :portals, :atomic_switch => true do |m|
      m.add_column :ssl_enabled, "tinyint(1) DEFAULT '0'"
      m.add_column :elb_dns_name, "varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL"
    end
  end

  def self.down
    Lhm.change_table :portals, :atomic_switch => true do |m|
      m.remove_column :ssl_enabled
      m.remove_column :elb_dns_name
    end
  end
end
