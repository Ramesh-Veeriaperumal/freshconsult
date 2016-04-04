class AddImportedToEsEnabledAccount < ActiveRecord::Migration
  def self.up
    add_column :es_enabled_accounts, :imported, :boolean, :default => true
  end

  def self.down
    remove_column :es_enabled_accounts, :imported
  end
end
