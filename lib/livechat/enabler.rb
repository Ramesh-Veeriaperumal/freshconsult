module Livechat::Enabler

	include Livechat::Token

  SUCCESS_CODES = [200, 201]
  RESPONSE_TYPE = 'application/json'.freeze

  LIVECHAT_ROUTE_MAPPINGS = [
    [ 'GET',    Net::HTTP::Get],
    [ 'PUT',    Net::HTTP::Put],
    [ 'POST',   Net::HTTP::Post],
    [ 'DELETE', Net::HTTP::Delete]
  ]
  HTTP_METHODS = Hash[*LIVECHAT_ROUTE_MAPPINGS.map { |i| [i[0], i[1]] }.flatten]

	def enable_livechat_feature
		response = livechat_request("create_site", livechat_create_request_params, 'sites', 'POST')
		if response && SUCCESS_CODES.include?(response[:status])
		  result = JSON.parse(response[:text])['data']
		  Account.current.chat_setting.update_attributes({ :active => true, :enabled => true, :site_id => result['site']['site_id']})
		  Account.current.main_chat_widget.update_attributes({ :widget_id => result['widget']['widget_id']})
		  create_widget_for_product
		  # added Livechat sync
		  # Livechat::Sync.new.sync_data_to_livechat(result['site_id'])
		  LivechatWorker.perform_async({:worker_method => "livechat_sync", :siteId => result['site']['site_id']})
		  "success"
		else
		  "error"
		end
	end

  def livechat_request(type, params, path, requestType)
    response_code = 200
    content_type  = RESPONSE_TYPE
    accept_type   = RESPONSE_TYPE
    response_type = RESPONSE_TYPE
    begin
      # request_url = live_chat_url + REST_URL[type.to_sym].to_s
      request_url = live_chat_url + "/" + path
      options = Hash.new
      auth_details = { :appId => ChatConfig["app_id"], :userId => User.current.id }

      #whitelist the allowed type(s)
      case type
        when "create_site"
          auth_details[:token]   = livechat_partial_token(User.current.id, User.current.privilege?(:admin_tasks))
        when "update_site", "export", "getExportUrl", "create_widget", "update_widget",
          "available", "get_agents_availability", "update_availability",
          "create_shortcode", "update_shortcode", "delete_shortcode",
          "get_shortcode"
          site_id  = Account.current.chat_setting.site_id
          auth_details[:siteId] = site_id
          auth_details[:token]   = livechat_token(site_id, User.current.id, User.current.privilege?(:admin_tasks))
        else
          Rails.logger.error("chat_helper.rb livechat_request called with invalid value for type: #{type}")
          NewRelic::Agent.notice_error(e,{:description => "#{Account.current.id} - Error occurred in livechat_request"})
          response_body = '{"result":"error"}'
          response_code = 500  # Internal server error
          return { :text=> response_body, :content_type => response_type, :status => response_code }
      end

      # unless type === "create_site"
      #   site_id  = Account.current.chat_setting.site_id
      #   auth_details[:siteId] = site_id
      #   auth_details[:token]   = livechat_token(site_id, User.current.id, User.current.privilege?(:admin_tasks))
      # else
      #   auth_details[:token]   = livechat_partial_token(User.current.id, User.current.privilege?(:admin_tasks))
      # end
      request_data      = params.merge(auth_details)
      if requestType == "GET" || requestType == "DELETE"
        options[:query] = request_data.collect{|k,v| [k.to_sym, v]}.to_h
      else
        options[:body] = request_data.to_json
      end
      options[:headers] = { "Accept" => accept_type, "Content-Type" => content_type}.delete_if{ |k,v| v.blank? }  # TODO: remove delete_if use and find any better way to do it in single line
      options[:timeout] = params[:timeout] || 15 #Returns status code 504 on timeout expiry 
      begin
        # proxy_request  = HTTParty::Request.new(HTTP_METHODS[type.to_sym], request_url, options)
        proxy_request  = HTTParty::Request.new(HTTP_METHODS[requestType], request_url, options)
        proxy_response = proxy_request.perform
        response_body  = proxy_response.body
        response_code  = proxy_response.code
        response_type  = proxy_response.headers['content-type']
      rescue Timeout::Error
        Rails.logger.error("Timeout trying to complete the request. \n#{params.inspect}")
        response_body = '{"result":"timeout"}'
        response_code = 504  # Timeout
      rescue => e
        Rails.logger.error("Error while processing proxy request::: #{e.message}\n#{e.backtrace.join("\n")}")
        response_body = '{"result":"error"}'
        response_code = 502  # Bad Gateway
      end
    rescue => e
      Rails.logger.error("Error while processing proxy request:::: #{params.inspect}. \n#{e.message}\n#{e.backtrace.join("\n")}")
      response_body = '{"result":"error"}'
      response_code = 500  # Internal server error
    end
    response_type = accept_type if response_type.blank?
    begin
      if proxy_response.present? && accept_type == "application/json" && !(response_type.start_with?("application/json") || response_type.start_with?("js"))
        response_body = proxy_response.parsed_response.to_json
        response_type = "application/json"
      end
    rescue => e
     Rails.logger.error("Error while parsing remote response.")
    end
    return { :text=> response_body, :content_type => response_type, :status => response_code }
  end

  private

  def livechat_create_request_params
    { 
      :options => { :widget => true },
      :attributes => {
        :external_id        => Account.current.id,
        :site_url           => Account.current.full_domain,
        :name               => Account.current.main_portal.name,
        :expires_at         => Account.current.subscription.next_renewal_at.utc,
        :suspended          => !Account.current.active?,
        :language           => Account.current.language ? Account.current.language : I18n.default_locale,
        :timezone           => Account.current.time_zone
      }
    }
  end

  def live_chat_url
    url = "http://" + ChatConfig["communication_url"]
    url = url + ":4000" if Rails.env == "development"
    return url
  end

  def create_widget_for_product
    products = Account.current.products
    unless products.blank?
      products.each do |product|
        if product.chat_widget.blank?
          product.build_chat_widget
          product.chat_widget.account_id = Account.current.id
          product.chat_widget.chat_setting_id = Account.current.chat_setting.id
          product.chat_widget.main_widget = false
          product.chat_widget.show_on_portal = false
          product.chat_widget.portal_login_required = false
          product.chat_widget.name = product.name
          product.chat_widget.save
        end
      end
    end
  end
end
