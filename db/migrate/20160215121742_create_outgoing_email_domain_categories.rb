class CreateOutgoingEmailDomainCategoriesTable < ActiveRecord::Migration
  shard :all

  def up
    create_table :outgoing_email_domain_categories do |t|
      t.integer    :account_id, :limit => 8, :null => false
      t.string     :email_domain, :limit => 253, :null => false
      t.integer    :category, :null => false
      t.boolean    :enabled, :default => false
      t.timestamps 
    end
    add_index :outgoing_email_domain_categories, [:account_id, :email_domain], :name => 'index_outgoing_email_domain_categories_on_account_id_and_domain', :unique => true
  end

  def down
    drop_table :outgoing_email_domain_categories
  end
end
