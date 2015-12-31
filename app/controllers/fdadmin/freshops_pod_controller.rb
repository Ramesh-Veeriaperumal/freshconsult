class Fdadmin::FreshopsPodController < Fdadmin::DevopsMainController

  VALID_METHODS = [:clear_domain_mapping_cache_for_pods,:check_domain_availability,:change_domain_mapping_for_pod]

  before_filter :validate_params, :only => :pod_endpoint

  def pod_endpoint
    response = send(params[:target_method])
    render :json => {:status => response}
  end

  def fetch_pod_info
    if params && params[:account_id] 
      domain_mapping = DomainMapping.find_by_account_id(params[:account_id] )
    elsif params && params[:domain_name]
      domain_mapping = DomainMapping.find_by_domain(params[:domain_name])
    end
    shard_mapping = ShardMapping.find_by_account_id(domain_mapping.account_id) if domain_mapping
    result = shard_mapping ? set_return_params(shard_mapping.pod_info,domain_mapping.domain,"Account found",200) : set_return_params
    
    respond_to do |format|
      format.json do 
        head result[:status]
        render :json => result and return
      end
    end
  end

  private
  def clear_domain_mapping_cache_for_pods
    key = MemcacheKeys::SHARD_BY_DOMAIN % { :domain => params[:domain] }
    return true if MemcacheKeys.delete_from_cache key
  end

  def check_domain_availability
    domain_mapping = DomainMapping.find_by_domain(params[:new_domain]) ? true : false
    return domain_mapping
  end

  def change_domain_mapping_for_pod
    domain_mapping = DomainMapping.find_by_account_id_and_domain(params[:account_id],params[:old_domain])
    begin 
      return true if domain_mapping.update_attribute(:domain,params[:new_domain])
    rescue
      return false
    end
  end

  def set_return_params(shard_mapping=nil,domain_mapping=nil,message="Account not found",status=404)
    {
      :pod_info => shard_mapping,
      :domain => domain_mapping,
      :message => message,
      :status => status
    }
  end

  def validate_params
    render :json => {:status => :error} and return unless VALID_METHODS.include?(params[:target_method].to_sym)
  end

end