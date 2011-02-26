class CreateHelpdeskSlaDetails < ActiveRecord::Migration
  def self.up
    create_table :helpdesk_sla_details do |t|
      t.string :name
      t.integer :account_id
      t.integer :priority
      t.integer :response_time
      t.integer :resolution_time
      t.integer :escalateto

      t.timestamps
    end
  end

  def self.down
    drop_table :helpdesk_sla_details
  end
end
