class RenameAndModifyInstalledAppUserCredentials < ActiveRecord::Migration
	def self.up
		rename_table :installed_app_user_credentials, :user_credentials
		change_table :user_credentials do |t|
		    t.change :installed_application_id, :bigint
		    t.change :user_id, :bigint
	    end
	    add_column	:user_credentials, :account_id, :bigint
	end

	def self.down
	    remove_column	:user_credentials, :account_id
		change_table :user_credentials do |t|
		    t.change :installed_application_id, :int
		    t.change :user_id, :int
	    end
	    rename_table :user_credentials, :installed_app_user_credentials
	end
end