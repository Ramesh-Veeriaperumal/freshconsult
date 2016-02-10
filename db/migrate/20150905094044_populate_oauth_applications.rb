class PopulateOauthApplications < ActiveRecord::Migration
  shard :all

  def up
    execute <<-SQL 
    INSERT INTO oauth_applications
      ( `name`, `uid`, `secret`, `redirect_uri`,
       `scopes`, `user_id`, `account_id`,
       `created_at`, `updated_at`)
    VALUES
      ('#{Marketplace::Constants::DEV_PORTAL_NAME}', '#{MarketplaceConfig::DEV_OAUTH_KEY}',
       '#{MarketplaceConfig::DEV_OAUTH_SECRET}', 
       '#{MarketplaceConfig::DEV_URL}/users/auth/freshdesk/callback', '', 
       '#{Integrations::Constants::SYSTEM_ACCOUNT_ID}', '#{Integrations::Constants::SYSTEM_ACCOUNT_ID}',
       NOW(), NOW()
      ),
      ('#{Marketplace::Constants::ADMIN_PORTAL_NAME}', '#{MarketplaceConfig::ADMIN_OAUTH_KEY}',
       '#{MarketplaceConfig::ADMIN_OAUTH_SECRET}',
       '#{MarketplaceConfig::API_URL}/users/auth/freshdesk/callback', '',
       '#{Integrations::Constants::SYSTEM_ACCOUNT_ID}', '#{Integrations::Constants::SYSTEM_ACCOUNT_ID}',
       NOW(), NOW()
      )
    SQL
  end

  def down
    execute <<-SQL
      DELETE FROM oauth_applications WHERE name IN (
        '#{Marketplace::Constants::DEV_PORTAL_NAME}', 
        '#{Marketplace::Constants::ADMIN_PORTAL_NAME}'
      )
    SQL
  end
end
