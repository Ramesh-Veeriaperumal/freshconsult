class AddSlaPolicyIdToCustomer < ActiveRecord::Migration
  def self.up
    add_column :customers, :sla_policy_id, :integer
  end

  def self.down
    remove_column :customers, :sla_policy_id
  end
end
