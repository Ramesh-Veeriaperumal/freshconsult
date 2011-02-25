class CreateHelpdeskFormCustomizers < ActiveRecord::Migration
  def self.up
    create_table :helpdesk_form_customizers do |t|
      t.string :name
      t.text :json_data
      t.integer :account_id

      t.timestamps
    end
  end

  def self.down
    drop_table :helpdesk_form_customizers
  end
end
