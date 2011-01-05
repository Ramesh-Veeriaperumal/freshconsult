class AddIsDefaultToHelpdeskSlaPolicies < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_sla_policies, :is_default, :boolean , :default => false
  end

  def self.down
    remove_column :helpdesk_sla_policies, :is_default
  end
end
