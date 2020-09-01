module Freshchat
  module AgentUtil
    include Freshchat::JwtAuthentication
    include Freshchat::Util

    SUCCESS_CODES = (200..204).freeze
    ACTION_MAPPINGS = {
      post: 'enable',
      put: 'update'
    }.freeze
    AGENT_PATH = 'v2/agents'.freeze
    USER_ROLE_MAPPINGS = {
      'Account Administrator' => 'ACCOUNT_ADMIN',
      'Administrator' => 'ADMIN',
      'Supervisor' => 'SUPER_USER',
      'Agent' => 'AGENT'
    }.freeze

    def valid_freshchat_agent_action?(agent)
      fchat_agent_create?(agent) || fchat_agent_update?(agent) || fchat_agent_destroy?(agent)
    end

    def handle_fchat_agent(agent)
      @agent = agent
      @user = @agent.user
      action = fetch_http_action
      log_request_and_call_freschat(action) do |connection|
        Rails.logger.debug "Freshchat Agent #{action} API called for Account #{account.id} and for Agent #{@agent.id}"
        connection.safe_send(action) do |request|
          request.body = safe_send("agent_#{action}_request_body") if ['post', 'put'].include?(action)
          Rails.logger.info "Freshchat Agent Request:: #{request.inspect} and connection #{connection.url_prefix.inspect} for Account #{account.id} and for Agent #{@agent.id}"
        end
      end
    end

    def fetch_freshchat_agent_emails
      agent_emails = []
      agents = fetch_freshchat_agents
      agents.deep_symbolize_keys!
      loop do
        agent_emails += agents[:agents].map { |agent_data| agent_data[:email] }
        break if agents[:links][:next_page].nil?

        agents = fetch_freshchat_agents(agents[:links][:next_page][:href])
        agents.deep_symbolize_keys!
      end

      agent_emails
    end

    def fetch_freshchat_agents(url = nil)
      fch_url = url.nil? ? "#{agent_host_url}?sort_by=email&items_per_page=30&sort_order=asc&page=1" : "https://#{freshchat_domain}#{url}"
      response = freshchat_request(fch_url)
      response.body
    end

    private

      def account
        ::Account.current
      end

      def fchat_agent_create?(agent)
        agent.safe_send(:transaction_include_action?, :create) && agent.freshchat_enabled && agent.additional_settings.try(:[], :freshchat).nil?
      end

      def fchat_agent_update?(agent)
        if agent.safe_send(:transaction_include_action?, :update)
          if agent.freshchat_enabled.nil? || agent.freshchat_enabled == agent.agent_freshchat_enabled?
            roles_changed?(agent)
          else
            account.omni_bundle_id ? true : standalone_account(agent)
          end
        end
      end

      def fchat_agent_destroy?(agent)
        agent.safe_send(:transaction_include_action?, :destroy) && account.omni_bundle_id && agent.additional_settings[:freshchat].present?
      end

      def roles_changed?(agent)
        (agent.user.previous_changes.keys & ['privileges']).present? && agent.agent_freshchat_enabled?
      end

      def standalone_account(agent)
        toggle_freschat_in_freshdesk(agent, false) if agent.freshchat_enabled == false
        agent.freshchat_enabled
      end

      def toggle_freschat_in_freshdesk(agent, value)
        additional_settings = agent.additional_settings
        additional_settings[:freshchat][:enabled] = value
        agent.update_attribute(:additional_settings, additional_settings)
      end

      def fetch_http_action
        if @agent.additional_settings.try(:[], :freshchat).nil?
          'post'
        elsif @agent.safe_send(:transaction_include_action?, :destroy)
          'delete'
        else
          'put'
        end
      end

      def log_request_and_call_freschat(action)
        response = yield(create_connection(action))
        if fchat_agent_success?(response)
          Rails.logger.debug "Freshchat Agent #{action} API Success. Response Body: #{response.body.inspect} for Account #{account.id} and for Agent #{@agent.id}"
          return safe_send("#{ACTION_MAPPINGS[action.to_sym]}_freshchat_channel", response) if ['post', 'put'].include?(action)
        else
          raise "Response status: #{response.status}:: Response Body: #{response.body['message'].presence || response.body['error_message']}"
        end
      rescue StandardError => e
        Rails.logger.error "Exception in Freshchat Agent #{action} API :: #{e.message} for Account #{account.id} and for Agent #{@agent.id}"
        NewRelic::Agent.notice_error(e, description: "Exception in Freshchat Agent #{action} API :: error: #{e.message} for Account #{account.id} and for Agent #{@agent.id}")
      end

      def create_connection(action)
        connection = Faraday.new(url: freshchat_agent_url(action)) do |conn|
          conn.request :json
          conn.adapter Faraday.default_adapter
          conn.response :json
        end
        connection.headers = {
          'x-fc-client-id' => Freshchat::Account::CONFIG[:freshchatClient],
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{freshchat_jwt_token}"
        }
        connection
      end

      def freshchat_agent_url(action)
        if action == 'post'
          "#{agent_host_url}?skip_email_activation=true"
        else
          fid_uuid = (action == 'delete' && freshid_uuid.presence) || @user.freshid_authorization.try(:uid)
          raise 'FreshID uuid not present' if fid_uuid.nil?
          "#{agent_host_url}/#{fid_uuid}?fid=true"
        end
      end

      def freshid_uuid
        account.freshid_org_v2_enabled? ? Freshid::V2::Models::User.find_by_email(@user.email.to_s).id : Freshid::User.find_by_email(@user.email.to_s).uuid
      end

      def freshchat_domain
        account.freshchat_account.api_domain
      end

      def agent_host_url
        "https://#{freshchat_domain}/#{AGENT_PATH}"
      end

      def agent_put_request_body
        request_body = {
          role_id: freshchat_role(@user.role_ids.min)
        }
        request_body[:is_deactivated] = !@agent.freshchat_enabled unless @agent.freshchat_enabled.nil?
        request_body
      end

      def agent_post_request_body
        request_body = {
          email: @user.email,
          phone: @user.phone,
          biography: @user.description,
          first_name: @user.full_name[:first_name],
          role_id: freshchat_role(@user.role_ids.min)
        }
        request_body[:avatar] = { url: @user.avatar_url } if @user.avatar.present?
        request_body[:last_name] = @user.full_name[:last_name] if @user.full_name[:last_name]
        request_body
      end

      def freshchat_role(role_id)
        account.roles_from_cache.map do |r|
          if r.id == role_id
            return ['Account Administrator', 'Administrator', 'Supervisor', 'Agent'].include?(r.name) ? USER_ROLE_MAPPINGS[r.name] : 'AGENT'
          end
        end
      end

      def fchat_agent_success?(response)
        SUCCESS_CODES.include?(response.status)
      end

      def enable_freshchat_channel(response)
        additional_settings = @agent.additional_settings
        enable_freshchat = { freshchat: { enabled: !response.body['is_deactivated'] } }
        additional_settings.merge!(enable_freshchat)
        @agent.update_attribute(:additional_settings, additional_settings)
      end

      def update_freshchat_channel(response)
        if @agent.additional_settings[:freshchat][:enabled] == response.body['is_deactivated']
          additional_settings = @agent.additional_settings
          additional_settings[:freshchat][:enabled] = !response.body['is_deactivated']
          @agent.update_attribute(:additional_settings, additional_settings)
        end
      end
  end
end
