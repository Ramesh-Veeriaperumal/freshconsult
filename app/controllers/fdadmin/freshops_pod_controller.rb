class Fdadmin::FreshopsPodController < Fdadmin::DevopsMainController

  VALID_METHODS = [:clear_domain_mapping_cache_for_pods,:check_domain_availability,:change_domain_mapping_for_pod,
                   :set_shard_mapping_for_pods,:remove_shard_mapping_for_pod]

  before_filter :validate_endpoint, :only => :pod_endpoint

  def clear_domain_mapping_cache_for_pods
   params[:domains].each {|domain| MemcacheKeys.delete_from_cache(MemcacheKeys::SHARD_BY_DOMAIN % {:domain => domain})}
  end

  def set_shard_mapping_for_pods
    shard_mapping = ShardMapping.new(params[:shard])
    shard_mapping.domains.build({:domain => params[:domain]})
    shard_mapping.save ? shard_mapping.id : nil
  end

  def remove_shard_mapping_for_pod
    shard_mapping = ShardMapping.find_by_account_id(params[:account_id])
    (shard_mapping && shard_mapping.destroy) ? true : false
  end

  def change_domain_mapping_for_pod
    domain_mapping = DomainMapping.find_by_account_id_and_domain(params[:account_id],params[:old_domain])
    (domain_mapping && domain_mapping.update_attribute(:domain,params[:new_domain])) ? domain_mapping.account_id : nil
  end

  def update_domain_mapping_for_pod
    if params[:operation].eql?("create")
      DomainMapping.new(params[:custom_portal]).save ? true : false
    else
      domain = params[:old_domain].blank? ? params[:custom_portal][:domain] : params[:old_domain]
      domain_mapping = DomainMapping.find_by_domain(domain)
      if domain_mapping && domain_mapping.account_id.eql?(params[:custom_portal][:account_id].to_i)
        return domain_mapping.update_attributes(params[:custom_portal]) ? true : false
      else
        return false
      end
    end
  end

  def create_hoot_suite_user
    Integrations::HootsuiteRemoteUser.new(params[:hootsuite_remote_user]).save
  end

  def create_shopify_user
    shopify_account = Integrations::ShopifyRemoteUser.find_by_account_id(params[:shopify_remote_user][:account_id])
    shopify_account ? shopify_account.remote_id = params[:shopify_remote_user][:remote_id] : 
    shopify_account = Integrations::ShopifyRemoteUser.new(params[:shopify_remote_user])
    shopify_account.save
  end

  def create_quickbooks_user
    quickbooks_account = Integrations::QuickbooksRemoteUser.find_by_remote_id(params[:quickbooks_remote_user][:remote_id])
    if quickbooks_account
      quickbooks_account.account_id = params[:quickbooks_remote_user][:account_id]
      quickbooks_account.configs = params[:quickbooks_remote_user][:configs]
    else
      quickbooks_account = Integrations::QuickbooksRemoteUser.new(params[:quickbooks_remote_user])
    end
    quickbooks_account.save
  end

  def create_global_ebay_integration
   Ecommerce::EbayRemoteUser.new(params[:ebay_remote_user]).save
  end

  def remove_remote_integration_mapping
    remote_user_record = RemoteIntegrationsMapping.find_by_remote_id(params[:remote_id])
    (remote_user_record && remote_user_record.destroy)
  end

  def remove_account_based_remote_mapping
    remote_user_record = RemoteIntegrationsMapping.find_by_account_id(params[:account_id])
    (remote_user_record && remote_user_record.destroy)
  end

  def check_domain_availability
    DomainMapping.find_by_domain(params[:new_domain]) ? true : false
  end

  def remove_domain_mapping_for_pod
    domain_mapping = DomainMapping.find_by_account_id_and_domain(params[:account_id],params[:domain])
    (domain_mapping && domain_mapping.destroy) ? true : false
  end

  def fetch_mobile_login_info
    mobile_info = {:full_domain => "",:sso_enabled => false ,:sso_logout_url => ""}
    select_slave_shard do 
      account = Account.find(params[:account_id])
      if account
        account.make_current
        mobile_info[:full_domain] = account.full_domain
        mobile_info[:sso_enabled] = account.sso_enabled? 
        mobile_info[:sso_logout_url] = account.sso_logout_url
      end
    end
    return mobile_info
  end

  def pod_endpoint
    status = send(params[:target_method])
    render :json => {:account_id => status}
  end

  def fetch_pod_info
    if params && (params[:account_id] || params[:domain_name])
      selected_finder , parameter = select_finder_by_parameter
      domain_record = DomainMapping.send(selected_finder , parameter)
      shard_details = ShardMapping.find_by_account_id(domain_record.account_id) if domain_record
      result = shard_details ? set_return_params(shard_details.pod_info,domain_record.domain,"Account found",200) : set_return_params
    end
    respond_to do |format|
      format.json do 
        head result[:status]
        render :json => result and return
      end
    end
  end

  def set_return_params(pod_info=nil,domain=nil,message="Account not found",status=404)
    return {
            :pod_info => pod_info,
            :domain => domain,
            :message => message,
            :status => status
          }
  end

  def select_finder_by_parameter
    return "find_by_account_id" , params[:account_id] if params[:account_id]
    return "find_by_domain" , params[:domain_name] if params[:domain_name]
  end

  def validate_endpoint
    return VALID_METHODS.include?(params[:target_method])
  end

end