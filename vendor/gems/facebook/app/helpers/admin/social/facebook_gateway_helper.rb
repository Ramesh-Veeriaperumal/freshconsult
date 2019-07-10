module Admin::Social::FacebookGatewayHelper
  include Facebook::GatewayJwt

  def gateway_facebook_page_mapping_details(page_id)
    begin
      accounts_count = -1
      accounts_detail = []
      response = HttpRequestProxy.new.fetch_using_req_params(build_gateway_param(page_id), build_request_params('get'), create_payload_option)
      return [response[:status], accounts_count, accounts_detail] unless response[:status] == 200

      response_text = JSON.parse response[:text]
      accounts_count = response_text['meta']['count'].to_i
      accounts_detail = response_text['pages'].map { |page| page[:id] }
      Rails.logger.info("Recived response from Gateway for Facebook page::#{page_id}, linked accounts count::#{accounts_count}, \
        response status::#{response[:status]}")
    rescue StandardError => e
      SocialErrorsMailer.deliver_facebook_exception(e, page_id: page_id, account_id: Account.current.id) unless Rails.env.test?
      Rails.logger.error("An exception happened while getting facebook accounts details from gateway: \
        facebookPage::#{page_id}, account::#{Account.current.id}, message::#{e.message}, backtrace::#{e.backtrace.join('\n')}")
      NewRelic::Agent.notice_error(e, description: "An exception happened while getting facebook accounts details from gateway:, \
        facebookPage::#{page_id}, account::#{Account.current.id}, message::#{e.message}}")
    end
    [response.try(:[], :status), accounts_count, accounts_detail]
  end

  def crud_gateway_request(page_id, action)
    HttpRequestProxy.new.fetch_using_req_params(build_gateway_param_with_body(page_id), build_request_params(action), create_payload_option)
  end

  def build_gateway_param(page_id)
    {
      domain: gateway_facebook_url,
      rest_url: "#{gateway_facebook_route}/#{page_id}"
    }
  end

  def build_request_params(action)
    {
      method: action,
      auth_header: authorization_token
    }
  end

  def build_gateway_param_with_body(page_id)
    {
      domain: gateway_facebook_url,
      rest_url: "#{gateway_facebook_route}/#{page_id}",
      body: create_payload_body
    }
  end

  def gateway_facebook_url
    FacebookGatewayConfig['service_url']
  end

  def gateway_facebook_route
    FacebookGatewayConfig['route']
  end

  def create_payload_option
    {
      'x-request-owner' => FacebookGatewayConfig['request_owner'],
      'x-request-id' => Thread.current[:message_uuid].try(:first).to_s
    }
  end

  def authorization_token
    "Bearer #{create_jwt_token}"
  end

  def create_payload_body
    {
      'pod' => ChannelFrameworkConfig['pod'],
      'region' => ChannelFrameworkConfig['region'],
      'freshdeskAccountId' => Account.current.id
    }.to_json
  end

  def create_jwt_token
    sign_payload(account_id: Account.current.id)
  end
end
