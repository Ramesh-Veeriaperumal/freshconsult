class Integrations::ShopifyRemoteUser < RemoteIntegrationsMapping

  validates_uniqueness_of :account_id,:remote_id

  before_save :create_shopify_user

  before_destroy :remove_from_global_pod

	def create_shopify_user
    if Fdadmin::APICalls.non_global_pods?
    	remote_user_record = self.as_json
    	response = Fdadmin::APICalls.connect_main_pod(self.as_json.merge(:target_method => :create_shopify_user))
    	return response["account_id"]
    end
  end

  def remove_from_global_pod
    args = {:target_method => :remove_account_based_remote_mapping , :account_id => self.account_id}
    super(args)
  end

end
