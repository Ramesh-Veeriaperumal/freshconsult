class Integrations::ShopifyRemoteUser < RemoteIntegrationsMapping

  validates_uniqueness_of :account_id

end
