class HttpRequestProxy

  def fetch(params, request)
    response_code = 200
    content_type = params[:content_type] || "application/json"
    accept_type = params[:accept_type] || "application/json"
    response_type = "application/json"
    begin
      method = request.env["REQUEST_METHOD"].downcase
      domain = params[:domain]
      method = params[:method] || method
      ssl_enabled = params[:ssl_enabled]
      resource = params[:resource]
      user = params[:username]
      pass = params[:password]
      entity_name = params[:entity_name]
      auth_header = request.headers['HTTP_AUTHORIZATION']
      user_agent = request.headers['HTTP_USER_AGENT'] + " Freshdesk"

      if entity_name.blank?
        post_request_body = params[:body] unless params[:body].blank?
      else
        if(content_type.include? "xml") # Based on the content type convert the form data into xml or json.
          post_request_body = (params[entity_name].to_xml :root => entity_name, :dasherize =>false)
        else
          post_request_body = (params[entity_name].to_json :root => entity_name)
        end
      end

      unless /http.*/.match(domain)
        http_s = ssl_enabled == "true"?"https":"http";
        domain = http_s+"://"+ domain
      end
      resource = resource ? "/" + resource : ""
      remote_url = domain + resource

      if auth_header.blank?
        auth_header = "Basic "+Base64.encode64("#{user}:#{pass}") unless (user.blank? or pass.blank?)
      end
      options = Hash.new
      options[:body] = post_request_body unless post_request_body.blank?  # if the form-data is sent from the integrated widget then set the data in the body of the 3rd party api.
      options[:headers] = {"Authorization" => auth_header, "Accept" => accept_type, "Content-Type" => content_type, "User-Agent" => user_agent}.delete_if{ |k,v| v.blank? }  # TODO: remove delete_if use and find any better way to do it in single line

      begin
        net_http_method = HTTP_METHOD_TO_CLASS_MAPPING[method.to_s]
        proxy_request = HTTParty::Request.new(net_http_method, remote_url, options)
        Rails.logger.debug "Sending request: #{proxy_request.inspect}"
        proxy_response = proxy_request.perform
        Rails.logger.debug "Received response: #{proxy_response.inspect}"
  
        # TODO Need to audit all the request and response calls to 3rd party api.
        response_body = proxy_response.body
        response_code = proxy_response.code
        response_type = proxy_response.header['content-type']
      rescue => e
        Rails.logger.error("Error during #{method.to_s}ing #{remote_url.to_s}. \n#{e.message}\n#{e.backtrace.join("\n")}")  # TODO make sure any password/apikey sent in the url is not printed here.
        response_body = '{"result":"error"}'
        response_code = 502  # Bad Gateway
      end
    rescue => e
      Rails.logger.error("Error while processing proxy request #{params.inspect}. \n#{e.message}\n#{e.backtrace.join("\n")}")  # TODO make sure any password/apikey sent in the url is not printed here.
      response_body = '{"result":"error"}'
      response_code = 500  # Internal server error
    end
    response_type = accept_type if response_type.blank?
    return {:text=>response_body, :content_type => response_type, :status => response_code}
  end

  HTTP_METHOD_TO_CLASS_MAPPING = {
            "get" => Net::HTTP::Get,
            "post" => Net::HTTP::Post,
            "put" => Net::HTTP::Put,
            "delete" => Net::HTTP::Delete
        }
end
