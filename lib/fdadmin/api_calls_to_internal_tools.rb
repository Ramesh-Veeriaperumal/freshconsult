module Fdadmin::APICallsToInternalTools

  def self.make_api_request_to_internal_tools(request_type,url_params,path_key,domain=nil)
    domain = @domain if @domain
    options = Hash.new
    options[:timeout] = 30
    options[:headers] = {"Accept" => "application/json", "Content-Type" => "application/json" }
    url_params.delete(:digest)
    url_params[:digest] = generate_md5_digest_params(url_params)
    options[:query] = url_params
    req_type = Fdadmin::ApiCallConstants::HTTP_METHOD_TO_CLASS_MAPPING[request_type]
    if Rails.env == "development"
      request_url = "http://#{domain}#{API_CONFIG_TOOLS[path_key]}"
    else
      request_url = "https://#{domain}#{API_CONFIG_TOOLS[path_key]}"
    end
    request = HTTParty::Request.new(req_type, request_url, options)
    Rails.logger.debug "Request POD URL: #{request_url}"
    begin
      response = request.perform
      Rails.logger.debug "Response in API CALL : #{response}"
    rescue Exception => e
      response = Response.new(503)
      Rails.logger.debug "Exception in performing API call: #{e}"
    end
    # if response.code == 200
    #   create_activity(request,response) if UPDATE_ACTIONS.include?(action_name.to_s) && response["status"] == "success"
    #   # record_exception if response.body.include?("status") && response["status"] == "error"
    # end
    return response
  end

  def self.generate_md5_digest_params(url_params)
    payload = ""
    url_params.each do |key , value |
      payload << "#{key}#{value.to_s}"
    end
    payload = payload.chars.sort.join
    sha_signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('MD5'), determine_api_key_supreme, payload)
    sha_signature
  end

  def self.determine_api_key_supreme
    return ServiceApiKey.find_by_service_name("supreme").api_key 
  end

end