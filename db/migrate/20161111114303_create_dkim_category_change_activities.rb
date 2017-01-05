class CreateDkimCategoryChangeActivities < ActiveRecord::Migration
  shard :all

  def up
    create_table :dkim_category_change_activities do |t|
      t.column   :account_id, "bigint unsigned", :null => false 
      t.column   :outgoing_email_domain_category_id, "bigint unsigned", :null => false 
      t.text     :details
      t.datetime :changed_on
      t.timestamps
    end

    add_index :dkim_category_change_activities, [:account_id, :outgoing_email_domain_category_id, :changed_on], 
              :name => 'index_dkim_activities_on_account_email_domain_changed_on'
  end

  def down
    drop_table :dkim_category_change_activities
  end
end
