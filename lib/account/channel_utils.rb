module Account::ChannelUtils
  include Livechat::Token

  JSON_RESPONSE_TYPE = 'application/json'.freeze
  LC_CREATE_SUCCESS_CODES = [200, 201].freeze
  def toggle_forums_channel(toggle_value = true)
    if toggle_value
      features.forums.save
      add_feature(:forums)
    else
      features.forums.destroy
      revoke_feature(:forums)
    end
    # to prevent trusted ip middleware caching the association cache
    clear_association_cache
  end

  def toggle_social_channel(toggle_value = true)
    toggle_additional_settings_for_channel('social', toggle_value)
  end

  def toggle_phone_channel(toggle_value = true)
    toggle_additional_settings_for_channel('phone', toggle_value)
  end

  def toggle_additional_settings_for_channel(channel, toggle_value)
    additional_settings = account_additional_settings.additional_settings || {}
    additional_settings["enable_#{channel}".to_sym] = toggle_value
    account_additional_settings.additional_settings = additional_settings
    account_additional_settings.save
  end

  def enable_forums_channel
    toggle_forums_channel
  end

  def disable_forums_channel
    toggle_forums_channel(false)
  end

  def enable_social_channel
    toggle_social_channel
  end

  def disable_social_channel
    toggle_social_channel(false)
  end

  def enable_phone_channel
    toggle_phone_channel
  end

  def disable_phone_channel
    toggle_phone_channel(false)
  end

  def enable_live_chat_channel
    response = livechat_request('create_site', livechat_create_request_params, 'sites', 'POST')
    if response && Account::ChannelUtils::LC_CREATE_SUCCESS_CODES.include?(response[:status])
      result = JSON.parse(response[:text])['data']
      chat_setting.update_attributes(active: true, enabled: true, site_id: result['site']['site_id'])
      main_chat_widget.update_attributes(widget_id: result['widget']['widget_id'])
      create_widget_for_products
      # added Livechat sync
      # Livechat::Sync.new.sync_data_to_livechat(result['site_id'])
      LivechatWorker.perform_async(worker_method: 'livechat_sync', siteId: result['site']['site_id'])
      'success'
    else
      'error'
    end
  end

  def phone_channel_enabled?
    (account_additional_settings.try(:additional_settings).try(:[], :enable_phone) == true)
  end

  def social_channel_enabled?
    (account_additional_settings.try(:additional_settings).try(:[], :enable_social) == true)
  end

  private

    def livechat_create_request_params
      {
        options: { widget: true },
        attributes: {
          external_id: id,
          site_url: full_domain,
          name: main_portal.name,
          expires_at: subscription.next_renewal_at.utc,
          suspended: subscription.suspended?,
          language: language || I18n.default_locale,
          timezone: time_zone
        }
      }
    end

    def livechat_request(type, params, path, requestType)
      response_code = 200
      content_type  = Account::ChannelUtils::JSON_RESPONSE_TYPE
      accept_type   = Account::ChannelUtils::JSON_RESPONSE_TYPE
      response_type = Account::ChannelUtils::JSON_RESPONSE_TYPE
      current_user = User.current
      begin
        # request_url = live_chat_url + REST_URL[type.to_sym].to_s
        request_url = live_chat_url + '/' + path
        options = {}
        auth_details = { appId: ChatConfig['app_id'], userId: current_user.id }
        if type === 'create_site'
          auth_details[:token] = livechat_partial_token(current_user.id)
        else
          site_id = chat_setting.site_id
          auth_details[:siteId] = site_id
          auth_details[:token] = livechat_token(site_id, current_user.id)
        end
        request_data      = params.merge(auth_details)
        options[:body]    = JSON.generate(request_data)
        options[:headers] = { 'Accept' => accept_type, 'Content-Type' => content_type }.delete_if { |k, v| v.blank? } # TODO: remove delete_if use and find any better way to do it in single line
        options[:timeout] = params[:timeout] || 15 # Returns status code 504 on timeout expiry
        begin
          # proxy_request  = HTTParty::Request.new(HTTP_METHODS[type.to_sym], request_url, options)
          proxy_request  = HTTParty::Request.new(ChatHelper::HTTP_METHODS[requestType], request_url, options)
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
        p "Error while processing proxy request:::: #{params.inspect}. \n#{e.message}\n#{e.backtrace.join("\n")}"
        Rails.logger.error("Error while processing proxy request:::: #{params.inspect}. \n#{e.message}\n#{e.backtrace.join("\n")}")
        response_body = '{"result":"error"}'
        response_code = 500 # Internal server error
      end
      response_type = accept_type if response_type.blank?
      begin
        if proxy_response.present? && accept_type == Account::ChannelUtils::JSON_RESPONSE_TYPE && !(response_type.start_with?(Account::ChannelUtils::JSON_RESPONSE_TYPE) || response_type.start_with?('js'))
          response_body = proxy_response.parsed_response.to_json
          response_type = Account::ChannelUtils::JSON_RESPONSE_TYPE
        end
      rescue
        Rails.logger.error('Error while parsing remote response.')
      end
      { text: response_body, content_type: response_type, status: response_code }
    end

    def live_chat_url
      url = 'http://' + ChatConfig['communication_url']
      url += ':4000' if Rails.env == 'development'
      url
    end

    def create_widget_for_products
      products.each do |product|
        product.create_chat_widget if product.chat_widget.blank?
      end
    end
end
