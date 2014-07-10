class CreateHelpdeskActivities < ActiveRecord::Migration
  def self.up
    create_table :helpdesk_activities do |t|
      t.integer :account_id
      t.text :description
      t.integer :notable_id
      t.string :notable_type

      t.timestamps
    end
  end

  def self.down
    drop_table :helpdesk_activities
  end
end
