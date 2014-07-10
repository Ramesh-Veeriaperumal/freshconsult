class CreateHelpdeskSlaPolicies < ActiveRecord::Migration
  def self.up
    create_table :helpdesk_sla_policies do |t|
      t.string :name
      t.text :description
      t.integer :account_id

      t.timestamps
    end
  end

  def self.down
    drop_table :helpdesk_sla_policies
  end
end
