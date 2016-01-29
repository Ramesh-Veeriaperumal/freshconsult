class CreateSubscriptionInvoices < ActiveRecord::Migration
  shard :all

  def up
    create_table :subscription_invoices do |t|
      t.string   :customer_name
      t.string   :chargebee_invoice_id
      t.datetime :generated_on
      t.text     :details
      t.decimal  :amount, :precision => 10, :scale => 2
      t.decimal  :sub_total, :precision => 10, :scale => 2
      t.string   :currency
      t.column   :account_id, "bigint unsigned", :null => false 
      t.column   :subscription_id, "bigint unsigned", :null => false 
      t.timestamps
    end
    
    add_index :subscription_invoices, [:account_id, :subscription_id, :generated_on], 
              :name => 'index_subscription_invoices_on_account_subscription_generated_on'
  end

  def down
    drop_table :subscription_invoices
  end
end