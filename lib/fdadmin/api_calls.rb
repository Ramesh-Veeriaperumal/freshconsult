module Fdadmin::APICalls

  include Fdadmin::ApiCallConstants
    
  def connect_main_pod(request_parameters)
    make_api_request_to_global(
      :post,
      request_parameters,
      PodConfig['pod_paths']['pod_endpoint'],
    "#{AppConfig["freshops_subdomain"][PodConfig['GLOBAL_POD']]}.#{AppConfig['base_domain'][Rails.env]}")
  end

  def self.make_api_request_to_global(request_type,url_params,path_key,domain)
    options = Hash.new
    options[:timeout] = AdminApiConfig['timeout']
    options[:headers] = {"Accept" => AdminApiConfig['accept'], "Content-Type" => AdminApiConfig['content_type'] }
    url_params.delete(:digest)
    url_params[:digest] = generate_md5_digest(url_params)
    options[:query] = url_params
    req_type = HTTP_METHOD_TO_CLASS_MAPPING[request_type]
    if Rails.env == "development"
      request_url = "http://#{domain}:3003#{path_key}"
    else
      request_url = "https://#{domain}#{path_key}"
    end
    request = HTTParty::Request.new(req_type, request_url, options)
    Rails.logger.debug "Initiating API Request Connecting to Global POD URL: #{request_url} with params:: #{url_params.inspect}"
    begin
      response = request.perform
      Rails.logger.debug "Response for #{request_url} : : : : #{response} "
    rescue Exception => e
      Rails.logger.debug "Exception in Response for #{request_url} : : : : #{e.inspect} "
      NewRelic::Agent.notice_error(e,{:description => "POD api call failed :#{url_params}"})
      raise e
    end
    return response
  end

  def generate_md5_digest(url_params)
    payload = ""
    url_params.each do |key , value |
      payload << "#{key}#{value.to_s}"
    end
    payload = payload.chars.sort.join
    sha_signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('MD5'), determine_api_key, payload)
    sha_signature
  end

  def determine_api_key
    app_name = get_app_name
    return ServiceApiKey.find_by_service_name(app_name).api_key 
  end

  def get_app_name
    return defined?(params) && params[:app_name] ? params[:app_name] : "freshopsadmin"
  end

  def handle_response(response)
    return false if response.code != 200
  end

  def non_global_pods?
    PodConfig['CURRENT_POD'] != PodConfig['GLOBAL_POD']
  end

  module_function :connect_main_pod,:generate_md5_digest,:non_global_pods?,:determine_api_key,:get_app_name

end