class AddMarketplaceGalleryToOauthApplications < ActiveRecord::Migration
  shard :all

  def up
    execute <<-SQL 
    INSERT INTO oauth_applications
      ( `name`, `uid`, `secret`, `redirect_uri`,
       `scopes`, `user_id`, `account_id`,
       `created_at`, `updated_at`)
    VALUES
      ('#{Marketplace::Constants::GALLERY_NAME}', '#{MarketplaceConfig::GALLERY_OAUTH_KEY}',
       '#{MarketplaceConfig::GALLERY_OAUTH_SECRET}', 
       '#{MarketplaceConfig::GALLERY_URL}/auth/callback', '', 
       '#{Integrations::Constants::SYSTEM_ACCOUNT_ID}', '#{Integrations::Constants::SYSTEM_ACCOUNT_ID}',
       NOW(), NOW()
      )
    SQL
  end

  def down
    execute <<-SQL
      DELETE FROM oauth_applications WHERE name IN ('#{Marketplace::Constants::GALLERY_NAME}')
    SQL
  end
end
