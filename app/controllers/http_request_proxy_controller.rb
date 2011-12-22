require 'httparty'

class HttpRequestProxyController < ApplicationController
  include HTTParty

  #TODO: covert the fetching and etc logic into an model.
  def fetch
    response_code = 200
    accept_type = "application/json"
    response_type = "application/json"
    response = ""
    begin
      method = request.env["REQUEST_METHOD"].downcase
      domain = params[:domain]
      method = params[:method] || method
      ssl_enabled = params[:ssl_enabled]
      resource = params[:resource]
      user = params[:username]
      pass = params[:password]
      entity_name = params[:entity_name]
      content_type = params[:content_type] || "application/xml"
      auth_header = request.headers['HTTP_AUTHORIZATION']

      if entity_name.blank?
        post_request_body = params[:body] unless params[:body].blank?
      else
        if(content_type.include? "xml") # Based on the content type convert the form data into xml or json.
          post_request_body = (params[entity_name].to_xml :root => entity_name) unless entity_name.nil?
        else
          post_request_body = (params[entity_name].to_json :root => entity_name) unless entity_name.nil?
        end
      end

      unless /http.*/.match(domain)
        http_s = ssl_enabled == "true"?"https":"http";
        domain = http_s+"://"+ domain
      end
      resource = resource ? "/" + resource : ""
      remote_url = domain + resource
      options = Hash.new
      options.store(:body, post_request_body) unless post_request_body.nil?  # if the form-data is sent from the integrated widget then set the data in the body to the 3rd party api.
      options.store(:headers, {"Authorization" => auth_header, "Accept" => accept_type, "Content-Type" => content_type}.delete_if{ |k,v| v.nil? })  # TODO: remove delete_if use and find any better way to do it in single line
      Rails.logger.debug "sending request to=#{remote_url}, options=#{options.to_s}, method=#{method}, http_s=#{http_s}, username=#{user.to_s}"
      self.class.basic_auth(user, pass) unless (user.nil? || pass.nil?)
  
      begin
        case method
          when "get" then 
            remote_response = self.class.get(remote_url, options)
          when "post" then 
            puts "post "+remote_url+ options.to_s
            remote_response = self.class.post(remote_url, options)
        end
  
        # TODO Need to audit all the request and response calls to 3rd party api.
        response_body = remote_response.body
        response_code = remote_response.code
        response_type = remote_response.header['content-type']
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
    Rails.logger.debug "response_body: #{response_body}, response_type: #{response_type}, response_code: #{response_code}, accept_type: #{accept_type}"
    response_type = accept_type if response_type.blank?
    render :text=>response_body, :content_type => response_type, :status => response_code
  end

end
