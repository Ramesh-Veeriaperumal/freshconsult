class AddLanguageToPortals < ActiveRecord::Migration
  def self.up
    add_column :portals, :language, :string , :default => 'en'
     Account.all.each do |account|
      account.main_portal.update_attribute(:language , account.language)
    end
    remove_column :accounts , :language
  end

  def self.down
    add_column :portals, :language, :string , :default => 'en'
    Account.all.each do |account|
      account.update_attribute(:language , account.main_portal.language)
    end
    remove_column :portals, :language
    
  end
end
