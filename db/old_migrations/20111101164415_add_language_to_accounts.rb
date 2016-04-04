class AddLanguageToAccounts < ActiveRecord::Migration
  def self.up
    add_column :accounts, :language, :string , :default => 'en'
  end

  def self.down
    remove_column :accounts, :language
  end
end
