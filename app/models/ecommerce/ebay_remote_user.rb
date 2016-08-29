class Ecommerce::EbayRemoteUser < RemoteIntegrationsMapping
  validates :remote_id, presence: true, uniqueness: true

  before_create :create_pod_ebay_remote_user 
  before_destroy :remove_from_global_pod

  def create_pod_ebay_remote_user
	  if Fdadmin::APICalls.non_global_pods? && !create_global_remote_user_record 
	    errors.add(:base,"#{I18n.t('admin.ecommerce.new.duplicate_account')}")
	    return false
	  end
	end

	def create_global_remote_user_record
	  remote_user_record = self.as_json
    response = Fdadmin::APICalls.connect_main_pod(self.as_json.merge(:target_method => :create_global_ebay_integration))
	  Rails.logger.debug("Response: #{response.inspect}")
	  return response["account_id"]
  end
end