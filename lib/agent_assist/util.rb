module AgentAssist
  module Util
    include Fdadmin::ApiCallConstants
    SUCCESS = 201
    LIST_BOTS_PATH = '/rest/api/v2/bots/agentassist/'.freeze
    def onboarding_headers
      {
        'Content-Type' => 'application/json',
        'client-id' => FreddySkillsConfig[:agent_assist][:client_id],
        'fbots-service' => 'bot-admin'
      }
    end

    def onboarding_body
      {
        'intrnlNm': 'Demo Bot',
        'chngdByUsr': api_current_user.email,
        'tmpltHsh': FreddySkillsConfig[:agent_assist][:template_hash],
        'clnt': {
          'clntId': current_account.id.to_s,
          'dmn': current_account.id.to_s,
          'eml': current_account.admin_email,
          'nm': current_account.name,
          'phn': '',
          'pln': 'AGENT_ASSIST',
          'prtl': 'portal new',
          'orgDmn': current_account.organisation.try(:domain),
          'wbst': current_account.name,
          'mtdtPrprts': {
            'prtl': current_account.full_domain
          }
        }
      }.to_json
    end

    def bot_list_headers
      {
        'Content-Type' => 'application/json',
        'external-client-id' => current_account.id.to_s,
        'product-id' => FreddySkillsConfig[:agent_assist][:product_id]
      }
    end

    def bot_list_body
      params.except(:version, :format, :controller, :action, :agent_assist).to_json
    end

    def options(headers, body)
      {
        headers: headers,
        body: body,
        timeout: 5
      }
    end

    def jwt_payload
      {
        domain: current_account.account_additional_settings.agent_assist_config[:domain],
        email: api_current_user.email,
        exp: Time.zone.now.to_i + 1.hour
      }
    end

    def construct_jwt_token(payload)
      JWT.encode payload, FreddySkillsConfig[:agent_assist][:jwt_secret], 'HS256', 'alg': 'HS256'
    end

    def execute_api_call(http_method, url, options)
      net_http_method = HTTP_METHOD_TO_CLASS_MAPPING[http_method.downcase.to_sym]
      http_request = HTTParty::Request.new(net_http_method, url, options)
      Rails.logger.info "Agent Assist Request Params :: #{HTTP_METHOD_TO_CLASS_MAPPING[http_method.downcase.to_sym]} #{url} #{options.inspect}"
      http_response = http_request.perform
      Rails.logger.info "Agent Assist Response :: #{http_response.body} #{http_response.code} #{http_response.message} #{http_response.headers.inspect} #{Thread.current[:message_uuid]}"
      http_response
    rescue StandardError => e
      Rails.logger.error "Error in AgentAssist API Call ::Exception:: A - #{current_account.id} #{e.message}  #{e.backtrace[0..10].join(', ')}"
      options_hash = {
        custom_params: {
          description: "Error in AgentAssist API Call::Exception:: #{e.message}",
          account_id: Account.current.id,
          request_id: Thread.current[:message_uuid].to_s
        }
      }
      NewRelic::Agent.notice_error(e, options_hash)
    end

    def onboard_agent_assist
      url = FreddySkillsConfig[:agent_assist][:onboard_url]
      http_response = execute_api_call('post', url, options(onboarding_headers, onboarding_body))
      if (http_response.is_a? Hash) && (http_response.code == SUCCESS)
        parsed_response = http_response.parsed_response
        current_account.account_additional_settings.update_agent_assist_config!(domain: parsed_response['content']['dmn'])
        @agent_assist_config[:domain] = parsed_response['content']['dmn']
      end
      http_response
    end

    def agent_assist_bots
      agent_assist_config = current_account.account_additional_settings.agent_assist_config
      return if agent_assist_config.nil?

      url = "https://#{agent_assist_config[:domain]}#{LIST_BOTS_PATH}?group_ids=#{params[:group_ids]}"
      @agent_assist_bots = execute_api_call('get', url, options(bot_list_headers, bot_list_body))
    end
  end
end
