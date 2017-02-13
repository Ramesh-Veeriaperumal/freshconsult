class AddColumnToOutgoingEmailDomainCategories < ActiveRecord::Migration
  shard :all

  def self.up
    Lhm.change_table :outgoing_email_domain_categories, :atomic_switch => true do |m|
      m.add_column :status,  "int(11) DEFAULT NULL"
      m.add_column :first_verified_at, :datetime
      m.add_column :last_verified_at, :datetime
      m.change_column :category, "int(11) DEFAULT NULL"
    end
  end

  def self.down
    Lhm.change_table :outgoing_email_domain_categories, :atomic_switch => true do |m|
      m.remove_column :status
      m.remove_column :first_verified_at
      m.remove_column :last_verified_at
      m.change_column :category, "int(11) NOT NULL"
    end
  end
end
