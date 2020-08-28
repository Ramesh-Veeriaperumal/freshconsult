module Freshcaller
  module AgentUtil
    include Freshcaller::JwtAuthentication
    include Freshcaller::Endpoints

    FRESHCALLER_ROLE_PRIVILEGES = {
      account_admin: :manage_account,
      admin: :admin_tasks,
      supervisor: :view_reports
    }.freeze

    ACTION_MAPPINGS = {
      post: 'create',
      patch: 'update'
    }.freeze

    SUCCESS_CODES = (200..204).freeze

    POST_TYPE = 'post'.freeze

    PATCH_TYPE = 'patch'.freeze

    def valid_fcaller_agent_action?(agent)
      fcaller_agent_create?(agent) || fcaller_agent_update?(agent) || fcaller_agent_destroy?(agent)
    end

    def handle_fcaller_agent(agent)
      @agent = agent
      @user = agent.user
      action = fetch_agent_action
      log_request_and_call_freshcaller(action) do
        update_to_freshcaller(action)
      end
    end

    def enable_freshcaller_agent(user, freshcaller_account_admin_id)
      unless user.nil?
        agent = user.agent
        agent.freshcaller_enabled = true
        agent.create_freshcaller_agent(agent: agent, fc_enabled: true, fc_user_id: freshcaller_account_admin_id)
        handle_fcaller_agent(agent) if account.freshcaller_enabled? && valid_fcaller_agent_action?(agent)
      end
    end

    def fetch_freshcaller_agent_emails
      agent_emails = []
      agents = fetch_freshcaller_agents
      agent_emails += agents[:data].map { |agent_data| agent_data[:attributes][:email] }
      agent_emails
    end

    def fetch_freshcaller_agents
      url = "#{freshcaller_url}/users?paginate=false"
      fcl_response = freshcaller_request({}, url, :get, email: account.admin_email)
      (JSON.parse fcl_response.body).deep_symbolize_keys!
    end

    private

      def account
        ::Account.current
      end

      def fcaller_agent_create?(agent)
        agent.safe_send(:transaction_include_action?, :create) && agent.freshcaller_enabled && agent.freshcaller_agent.try(:fc_enabled).nil?
      end

      def fcaller_agent_update?(agent)
        if agent.safe_send(:transaction_include_action?, :update)
          if agent.freshcaller_enabled.nil? || agent.freshcaller_enabled == agent.agent_freshcaller_enabled?
            agent_properties_changed?(agent)
          else
            account.omni_bundle_id ? true : standalone_freshcaller_account?(agent)
          end
        end
      end

      def fcaller_agent_destroy?(agent)
        agent.safe_send(:transaction_include_action?, :destroy) && account.omni_bundle_id && agent.freshcaller_agent.present?
      end

      def standalone_freshcaller_account?(agent)
        agent.freshcaller_agent.update_attributes!(fc_enabled: agent.freshcaller_enabled) if agent.freshcaller_enabled == false
        agent.freshcaller_enabled
      end

      def agent_properties_changed?(agent)
        (agent.user.previous_changes.keys & ['privileges', 'email']).present? && agent.agent_freshcaller_enabled?
      end

      def fetch_agent_action
        @agent.freshcaller_agent.nil? ? POST_TYPE : PATCH_TYPE
      end

      def log_request_and_call_freshcaller(action)
        Rails.logger.debug "Freshcaller Agent #{action} API called for Account #{account.id} and for Agent #{@agent.id}"
        response = yield
        parsed_response = response.parsed_response
        if fcaller_agent_success?(response)
          return safe_send("#{ACTION_MAPPINGS[action.to_sym]}_freshcaller_agent", parsed_response)
        else
          raise "Response status: #{response.code}:: Body: #{response.message}:: #{response.body}"
        end
      rescue StandardError => e
        Rails.logger.error "Exception in Freshcaller Agent #{action} API :: #{e.message} for Account #{account.id} and for Agent #{@agent.id}"
        NewRelic::Agent.notice_error(e, description: "Exception in Freshcaller Agent #{action} API :: error: #{e.message} for Account #{account.id} and for Agent #{@agent.id}")
      end

      def update_to_freshcaller(action)
        freshcaller_request(add_agent_params(action), freshcaller_agent_url(action), action.to_sym, email: ::User.current.email)
      end

      def add_agent_params(action)
        request_body = {
          data: {
            attributes: {
              name: @user.name,
              phone: @user.phone,
              language: @user.language || account.language
            },
            relationships: {
              user_emails: {
                data: [{
                  type: 'user_emails',
                  attributes: {
                    email: @user.email,
                    primary_email: true
                  }
                }]
              },
              roles: {
                data: [{
                  name: deduct_freshcaller_role,
                  type: 'roles'
                }]
              }
            },
            role: deduct_freshcaller_role,
            type: 'users'
          }
        }
        request_body[:data][:attributes][:deleted] = !@agent.freshcaller_enabled if action == 'patch' && add_is_deleted?
        request_body
      end

      def deduct_freshcaller_role
        deducted_role = FRESHCALLER_ROLE_PRIVILEGES.detect do |k, v|
          @user.privilege? v
        end.try(:first)
        deducted_role || :agent
      end

      def add_is_deleted?
        (!@agent.freshcaller_enabled.nil? || @agent.safe_send(:transaction_include_action?, :destroy))
      end

      def freshcaller_agent_url(action)
        if action == 'patch'
          raise 'Freshcaller UserID not present' if fcaller_user_id.nil?

          freshcaller_update_agent_url(fcaller_user_id)
        else
          freshcaller_add_agent_url
        end
      end

      def fcaller_user_id
        @agent.freshcaller_agent.try(:fc_user_id)
      end

      def fcaller_agent_success?(result)
        SUCCESS_CODES.include?(result.code)
      end

      def create_freshcaller_agent(result)
        @agent.create_freshcaller_agent(
          fc_enabled: !parse_response(result)[:is_deleted],
          fc_user_id: parse_response(result)[:fc_user_id]
        )
      end

      def update_freshcaller_agent(result)
        is_deleted = parse_response(result)[:is_deleted]
        @agent.freshcaller_agent.update_attributes(fc_enabled: !is_deleted, fc_user_id: parse_response(result)[:fc_user_id]) if (is_deleted == @agent.freshcaller_agent.try(:fc_enabled)) && @agent.safe_send(:transaction_include_action?, :update)
      end

      def parse_response(result)
        {
          is_deleted: result.try(:[], 'data').try(:[], 'attributes').try(:[], 'deleted'),
          fc_user_id: result.try(:[], 'data').try(:[], 'id')
        }
      end
  end
end
