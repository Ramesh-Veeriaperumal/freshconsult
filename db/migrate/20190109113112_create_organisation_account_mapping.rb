class CreateOrganisationAccountMapping < ActiveRecord::Migration
  shard :none
  def up
    create_table :organisation_account_mappings do |t|
      t.column  :account_id, "bigint unsigned", :null => false
      t.column  :organisation_id, "bigint unsigned", :null => false
      t.timestamps
    end
    add_index :organisation_account_mappings, [:account_id], :name => 'index_organisations_on_account_id', unique: true
    add_index :organisation_account_mappings, [:organisation_id], :name => 'index_organisations_on_organisation_id'
  end

  def down
    drop_table :organisation_account_mappings
  end
end
