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

  def check_domain_availability
    DomainMapping.find_by_domain(params[:new_domain]) ? true : false
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