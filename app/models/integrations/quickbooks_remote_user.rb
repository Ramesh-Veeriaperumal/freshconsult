class Integrations::QuickbooksRemoteUser < RemoteIntegrationsMapping

	validates_uniqueness_of :account_id

end
