class CreateOrganisation < ActiveRecord::Migration
  shard :none
  def up
    create_table :organisations do |t|
      t.column  :organisation_id, "bigint unsigned", :null => false
      t.column  :domain, :string, :null => false
      t.column  :name, :string, :null => true
      t.column  :alternate_domain, :string, :null => true
      t.timestamps
    end
    add_index :organisations, [:organisation_id], :name => 'index_organisations_on_organisation_id', :unique => true
    add_index :organisations, [:domain], :name => 'index_organisations_on_domain', :unique => true
  end

  def down
    drop_table :organisations
  end
end
