module Fdadmin::PodHelperMethods

def verify_signature
    payload = ""
    request.query_parameters.each do |key , value |
      payload << "#{key}#{value.to_s}" unless key.to_s == "digest"
    end
    sha_signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('MD5'), determine_api_key, payload)
    if sha_signature != params[:digest]
       Rails.logger.debug(": : : SIGNATURE VERIFICATION FAILED : : :")
      render :json => {:message => "Authorization status failed"}, :status => 401 and return
    end
    Rails.logger.debug(": : : -> SHA SIGNATURE VERIFIED <- : : :")
  end

  def determine_api_key
    app_name = params[:app_name] || "freshopsadmin"
    return ServiceApiKey.find_by_service_name(app_name).api_key 
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
end