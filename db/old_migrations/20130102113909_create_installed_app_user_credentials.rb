class CreateInstalledAppUserCredentials < ActiveRecord::Migration
  def self.up
    create_table :installed_app_user_credentials do |t|
      t.integer :installed_application_id
      t.integer :user_id
      t.text :auth_info
      t.timestamps
    end
  end

  def self.down
    drop_table :installed_app_user_credentials
  end
end
