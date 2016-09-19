class HttpRequestProxy

  include Integrations::OauthHelper
  include HttpProxyMethods
  include Fdadmin::ApiCallConstants

  PROHIBITED_ADDRESSES = [
    "0.0.0.0/8",
    "255.255.255.255/32",
    "127.0.0.0/8",
    "10.0.0.0/8",
    "169.254.0.0/16",
    "172.16.0.0/12",
    "192.168.0.0/16",
    "224.0.0.0/4",
    "fc00::/7",
    "fe80::/10",
    "::1"].map {|a| IPAddr.new(a) }.freeze

  ACCEPT_TYPES = ['application/json', 'application/xml', 'text/plain', 'text/xml', 'application/atom+xml', 'application/jsonp']

  XML_BLACKLIST_ATTRIBUTES = ["href", "onclick", "onblur", "onchange", "ondblclick", "onfocus", "onkeydown", "onkeypress", "onkeyup",
    "onload", "onmousedown", "onmousemove", "onmouseout", "onmouseover", "onmouseup", "onselect", "onunload", "onbroadcast", "onclose",
    "oncommand", "oncommandupdate", "oncontextmenu", "ondrag", "ondragdrop", "ondragend", "ondragenter", "ondragexit", "ondraggesture",
    "ondragover", "oninput", "onoverflow", "onpopuphidden", "onpopuphiding", "onpopupshowing", "onpopupshown", "onsyncfrompreference",
    "onsynctopreference", "onunderflow"].map {|attr| "//@#{attr}"}.freeze

  TIMEOUT = 10

  def fetch(params, request)
    unless(request.blank?)
      method = request.env["REQUEST_METHOD"].downcase
      auth_header = request.headers['HTTP_AUTHORIZATION']
      user_agent = request.headers['HTTP_USER_AGENT']
    end
    requestParams = {:method => method, :auth_header => auth_header, :user_agent => user_agent}
    fetch_using_req_params(params, requestParams)
  end

  def fetch_using_req_params(params, requestParams, customHeaders=nil)
    response_code = 200
    content_type = params[:content_type] || "application/json"
    accept_type = params[:accept_type] || "application/json"
    response_type = "application/json"
    begin
      method = requestParams[:method]
      auth_header = requestParams[:auth_header]
      user_agent = requestParams[:user_agent]? requestParams[:user_agent] + " Freshdesk" :  "Freshdesk"
      domain = params[:domain]
      method = params[:method] || method
      method = method.downcase
      ssl_enabled = params[:ssl_enabled]
      rest_url = params[:rest_url]
      encode_url = params.fetch(:encode_url, true)
      user = params[:username]
      pass = params[:password]
      entity_name = params[:entity_name]
      if entity_name.blank?
        post_request_body = params[:body] unless params[:body].blank?
      else
        if(content_type.include? "xml") # Based on the content type convert the form data into xml or json.
          post_request_body = (params[entity_name].to_xml :root => entity_name, :dasherize =>false)
        else
          post_request_body = (params[entity_name].to_json :root => entity_name)
        end
      end

      if (params[:encode_params])
        encode_params = JSON.parse(params[:encode_params])
        rest_url += '?'
        encode_params.each do |k, v|
          rest_url += k + "=" + ERB::Util.url_encode(v)
        end
      end

      unless /http.*/.match(domain)
        http_s = ssl_enabled == "true"? "https":"http";
        domain = http_s+"://"+ domain
      end
      rest_url = rest_url ? "/" + rest_url : ""
      user_current = User.current
      rest_url = replace_placeholders(domain, rest_url,
        user_current) if user_current and user_current.agent? and params[:use_placeholders]
      remote_url = domain + rest_url
      remote_url = Liquid::Template.parse(remote_url).render("password"=>params[:password])

      if auth_header.blank?
        auth_header = "Basic "+Base64.strict_encode64("#{user}:#{pass}") unless (user.blank? or pass.blank?)
      end
      
      options = Hash.new
      options[:body] = post_request_body unless post_request_body.blank?  # if the form-data is sent from the integrated widget then set the data in the body of the 3rd party api.
      options[:headers] = {"Authorization" => auth_header, "Accept" => accept_type, "Content-Type" => content_type, "User-Agent" => user_agent}.delete_if{ |k,v| v.blank? }  # TODO: remove delete_if use and find any better way to do it in single line
      options[:headers] = options[:headers].merge(params[:custom_auth_header]) unless params[:custom_auth_header].blank?
      options[:headers] = options[:headers].merge(customHeaders) unless (customHeaders.nil? or customHeaders.empty?)
      timeout = params[:timeout].to_i
      options[:timeout] = timeout.between?(1, TIMEOUT)  ? timeout : TIMEOUT #Returns status code 504 on timeout expiry
      options[:timeout] = 30 if params[:domain].eql? "https://api.workflowmax.com"
      verify_url(remote_url, encode_url)
      begin
        if (params[:auth_type] == 'OAuth1')
          send_req_options = Hash.new
          send_req_options[:app_name] = params[:app_name]
          send_req_options[:method] = HTTP_METHOD_TO_SYMBOL_MAPPING[method.downcase]
          send_req_options[:url] = remote_url
          send_req_options[:body] = params[:body]
          send_req_options[:headers] = {'Accept' => accept_type, 'Content-Type' => content_type}

          proxy_response = get_oauth1_response(send_req_options)

          proxy_response.body = Hash.from_xml(proxy_response.body).to_json if (proxy_response.body.include? 'xml') # always returns JSON
          response_type = content_type
          Rails.logger.debug "Response Body: #{proxy_response.body}"
          Rails.logger.debug "Response Code: #{proxy_response.code}"
        else
          if !Rails.env.development? && Integrations::PROXY_SERVER["host"].present? #host will not be present for layers other than integration layer.
            options[:http_proxyaddr] = Integrations::PROXY_SERVER["host"]
            options[:http_proxyport] = Integrations::PROXY_SERVER["port"]
          end
          net_http_method = HTTP_METHOD_TO_CLASS_MAPPING[method.to_sym]
          final_url       = encode_url ? URI.encode(remote_url) : remote_url
          proxy_request   = HTTParty::Request.new(net_http_method, final_url, options)
          Rails.logger.debug "Sending request: #{proxy_request.inspect}"
          proxy_response = proxy_request.perform
          Rails.logger.debug "Response Body: #{proxy_response.body}"
          Rails.logger.debug "Response Code: #{proxy_response.code}"
          Rails.logger.debug "Response Headers: #{proxy_response.headers.inspect}"
        end
        # TODO Need to audit all the request and response calls to 3rd party api.
        response_body = proxy_response.body
        response_code = proxy_response.code
        response_type = proxy_response.content_type unless (params[:auth_type] == 'OAuth1')
        
        if accept_type == "application/json" && !(response_type == "application/json" || response_type == "js")
          response_body = proxy_response.parsed_response.to_json
          response_type = "application/json"
        end

        if proxy_response.present? && ACCEPT_TYPES.exclude?(response_type)
          if valid_json?(response_body)
            response_type = "application/json"
          elsif valid_xml?(response_body)
            response_type = "application/xml"
          else
            response_type = "application/json"
            response_body = proxy_response.parsed_response.to_json
          end
        end
        if (response_type.include?('xml') && params['app_name'] != 'constantcontact')
          parsed_xml = Nokogiri::XML(response_body)
          parsed_xml.remove_namespaces!
          parsed_xml.xpath('//script', *XML_BLACKLIST_ATTRIBUTES).remove
          response_body = parsed_xml.to_xml(:save_with => Nokogiri::XML::Node::SaveOptions::AS_XML)
        end
      rescue Timeout::Error
        Rails.logger.error("Timeout trying to complete the request. \n#{params.inspect}")
        response_body = '{"result":"timeout"}'
        response_code = 504  # Timeout
      rescue => e
        Rails.logger.error("Error during #{method.to_s}ing #{remote_url.to_s}. \n#{e.message}\n#{e.backtrace.join("\n")}")  # TODO make sure any password/apikey sent in the url is not printed here.
        response_body = '{"result":"error"}'
        response_code = 502  # Bad Gateway
      end
    rescue => e
      Rails.logger.error("Error while processing proxy request #{params.inspect}. \n#{e.message}\n#{e.backtrace.join("\n")}")  # TODO make sure any password/apikey sent in the url is not printed here.
      response_body = '{"result":"error"}'
      response_code = 500  # Internal server error
      NewRelic::Agent.notice_error(e)
    end
    response_type = accept_type if response_type.blank?
    begin
      x_headers = {}
      if proxy_response.present?
        proxy_response.headers.map { |key, value|
          x_headers[key] = value if key.start_with?("x-")
        }
        
      end
    rescue => e
     Rails.logger.error("Error while parsing remote response.\n#{e.message}\n#{e.backtrace.join('\n')}")
    end
    return {:text=>response_body, :content_type => response_type, :status => response_code, 'x-headers' => x_headers}
  end

  def verify_url(url_to_check, encode_url)
    url_to_check = URI.encode(url_to_check) if encode_url
    uri = URI.parse(url_to_check)

    ip_to_check = IPSocket::getaddress(uri.host)
    PROHIBITED_ADDRESSES.each do |addr|
      if addr === ip_to_check
        raise "Invalid local address #{uri.host}"
      end
    end
  end

  def valid_json?(data)
    begin
      JSON.parse(data)
      return true
    rescue JSON::ParserError => e
      return false
    end
  end

  def valid_xml?(data)
    begin
      Hash.from_xml(data)
      return true
    rescue Nokogiri::XML::SyntaxError => e
      return false
    end
  end
  
end
