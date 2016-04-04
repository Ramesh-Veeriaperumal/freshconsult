class AddCustomDomainAndMultipleEmailsFeatures < ActiveRecord::Migration
  def self.up
    execute("INSERT INTO features(type, account_id, created_at, updated_at) SELECT 'CustomDomainFeature', id, now(), now() from accounts")
    execute("INSERT INTO features(type, account_id, created_at, updated_at) SELECT 'MultipleEmailsFeature', id, now(), now() from accounts")
	end

	def self.down
  	execute("delete from features where type = 'CustomDomainFeature'")
    execute("delete from features where type = 'MultipleEmailsFeature'")
	end
end
