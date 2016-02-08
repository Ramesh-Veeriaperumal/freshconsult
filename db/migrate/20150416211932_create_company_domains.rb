class CreateCompanyDomains < ActiveRecord::Migration
  shard :all
  
  def migrate(direction)
    self.send(direction)
  end

  def up
    create_table :company_domains do |t|
      t.column :account_id, "bigint unsigned"
      t.integer  :company_id, :limit => 8
      t.string   :domain
      t.timestamps
    end

    add_index :company_domains, [:account_id, :company_id], :name => "index_for_company_domains_on_account_id_and_company_id"
    add_index :company_domains, [:account_id, :domain], :name => "index_for_company_domains_on_account_id_and_domain", :length => {:account_id=>nil, :domain=>20}
  end

  def down
    drop_table :company_domains
  end

end
