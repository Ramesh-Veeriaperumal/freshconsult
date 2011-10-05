class AddAccountIdToWfFilters < ActiveRecord::Migration
  def self.up
    add_column :wf_filters, :account_id, :integer
  end

  def self.down
    remove_column :wf_filters, :account_id
  end
end
