class AddImportDmsToSocialFacebookPages < ActiveRecord::Migration
  def self.up
    add_column :social_facebook_pages, :import_dms, :boolean , :default => true
    add_column :social_facebook_pages, :reauth_required, :boolean , :default => false
    add_column :social_facebook_pages, :last_error, :text 
  end

  def self.down
    remove_column :social_facebook_pages, :import_dms
    remove_column :social_facebook_pages, :reauth_required
    remove_column :social_facebook_pages, :last_error
  end
end
