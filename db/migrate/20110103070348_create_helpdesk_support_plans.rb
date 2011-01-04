class CreateHelpdeskSupportPlans < ActiveRecord::Migration
  def self.up
    create_table :helpdesk_support_plans do |t|
      t.string :name
      t.text :description
      t.integer :account_id
      t.boolean :email
      t.boolean :phone
      t.boolean :community
      t.boolean :twitter
      t.boolean :facebook

      t.timestamps
    end
  end

  def self.down
    drop_table :helpdesk_support_plans
  end
end
