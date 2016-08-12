class Integrations::HootsuiteRemoteUser < RemoteIntegrationsMapping

	before_validation :create_hootsuite_pod

	before_destroy :remove_from_global_pod

	validates :remote_id, presence: true

	def create_hootsuite_pod
    if Fdadmin::APICalls.non_global_pods?
    remote_user_record = self.as_json
    response = Fdadmin::APICalls.connect_main_pod(self.as_json.merge(:target_method => :create_hoot_suite_user))
    return response["account_id"]
    end
  end

end
