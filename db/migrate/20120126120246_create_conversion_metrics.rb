class CreateConversionMetrics < ActiveRecord::Migration
  def self.up
    create_table :conversion_metrics do |t|
      t.column :account_id,"bigint unsigned"
      t.string :referrer
      t.string :landing_url
      t.string :first_referrer
      t.string :first_landing_url
      t.string :country
      t.string :language
      t.string :search_engine
      t.string :keywords
      t.string :device
      t.string :browser
      t.string :os
      t.float :offset
      t.boolean :is_dst
      t.integer :visits
      t.text :session_json

      t.timestamps
    end
  end

  def self.down
    drop_table :conversion_metrics
  end
end
