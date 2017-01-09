class CreateDkimRecords < ActiveRecord::Migration
  shard :all
  
  def up
    create_table :dkim_records do |t|
      t.integer  :sg_id
      t.integer  :sg_user_id
      t.integer  :sg_category_id
      t.string   :record_type
      t.string   :sg_type
      t.string   :host_name
      t.string   :host_value # varchar not enough
      t.string   :fd_cname
      t.boolean  :customer_record, :default => false
      t.boolean  :status, :default => false
      t.column   :outgoing_email_domain_category_id, "bigint unsigned", :null => false 
      t.column   :account_id, "bigint unsigned", :null => false 
      t.timestamps
    end

    add_index :dkim_records, [:outgoing_email_domain_category_id, :status], 
              :name => 'index_dkim_records_on_email_domain_status'
  end

  def down
    drop_table :dkim_records
  end
end
