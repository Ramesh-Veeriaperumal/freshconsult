class DropTableHelpdeskSupportPlans < ActiveRecord::Migration
  def self.up
    drop_table :helpdesk_support_plans
  end

  def self.down
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
end
