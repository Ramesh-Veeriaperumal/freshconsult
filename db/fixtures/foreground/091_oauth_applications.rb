Doorkeeper::Application.seed_many(:name, :account_id,
  [{ 
    :name          => "#{Marketplace::Constants::DEV_PORTAL_NAME}",
    :uid           => "#{MarketplaceConfig::DEV_OAUTH_KEY}",
    :secret        => "#{MarketplaceConfig::DEV_OAUTH_SECRET}",
    :redirect_uri  => "#{MarketplaceConfig::DEV_URL}/users/auth/freshdesk/callback",
    :scopes        => '',
    :user_id       => Integrations::Constants::SYSTEM_ACCOUNT_ID,
    :account_id    => Integrations::Constants::SYSTEM_ACCOUNT_ID
  },
  { 
    :name          => "#{Marketplace::Constants::ADMIN_PORTAL_NAME}",
    :uid           => "#{MarketplaceConfig::ADMIN_OAUTH_KEY}",
    :secret        => "#{MarketplaceConfig::ADMIN_OAUTH_SECRET}",
    :redirect_uri  => "#{MarketplaceConfig::ADMIN_URL}/users/auth/freshdesk/callback",
    :scopes        => '',
    :user_id       => Integrations::Constants::SYSTEM_ACCOUNT_ID,
    :account_id    => Integrations::Constants::SYSTEM_ACCOUNT_ID
  },
  { :name          => "#{Marketplace::Constants::GALLERY_NAME}",
    :uid           => "#{MarketplaceConfig::GALLERY_OAUTH_KEY}",
    :secret        => "#{MarketplaceConfig::GALLERY_OAUTH_SECRET}",
    :redirect_uri  => "#{MarketplaceConfig::GALLERY_URL}/auth/callback",
    :scopes        => '',
    :user_id       => Integrations::Constants::SYSTEM_ACCOUNT_ID,
    :account_id    => Integrations::Constants::SYSTEM_ACCOUNT_ID
  }]
)
