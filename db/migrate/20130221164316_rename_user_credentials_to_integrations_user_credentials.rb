class RenameUserCredentialsToIntegrationsUserCredentials < ActiveRecord::Migration
	def self.up
		rename_table :user_credentials, :integrations_user_credentials
	end

	def self.down
		rename_table :integrations_user_credentials, :user_credentials
	end
end