class Integrations::GoogleRemoteAccount < RemoteIntegrationsMapping

  validates_uniqueness_of :account_id

end
