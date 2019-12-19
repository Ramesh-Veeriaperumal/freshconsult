module Freshcaller
  module AgentUtil
    include Freshcaller::JwtAuthentication
    include Freshcaller::Endpoints

    FRESHCALLER_ROLE_PRIVILEGES = {
      :account_admin => :manage_account,
      :admin => :admin_tasks,
      :supervisor => :view_reports
    }

    def freshcaller_enabled?(agent)
      agent.account.freshcaller_enabled?
    end

    def save_fc_agent?(agent)
      %i[create update].any? { |transact_type| agent.safe_send(:transaction_include_action?, transact_type) } &&
        freshcaller_enabled?(agent) && !agent.freshcaller_enabled.nil? &&
        agent.freshcaller_agent.try(:fc_enabled) != agent.freshcaller_enabled
    end

    def create_update_fc_agent(agent)
      if agent.freshcaller_enabled
        add_response = add_agent_to_freshcaller(agent)
        parsed_response = add_response.parsed_response
        if fc_agent_created?(add_response)
          return create_freshcaller_agent(agent, parsed_response)
        elsif fc_agent_limit?(parsed_response)
          return agent.errors[:base] << :freshcaller_agent_limit
        elsif fc_agent_already_present?(agent, parsed_response)
          return agent.errors[:base] << :freshcaller_agent_present
        elsif fc_error?(add_response)
          return :unable_to_perform
        end
      end
      agent.freshcaller_agent.update_attributes!(fc_enabled: agent.freshcaller_enabled || false)
    end

    def add_agent_params(agent)
      {
        data: {
          attributes: {
            name: agent.user.name
          },
          relationships: {
            user_emails: {
              data: [{
                type: 'user_emails',
                attributes: {
                  email: agent.user.email,
                  primary_email: true
                }
              }]
            },
            roles: {
              data: [{
                name: deduct_freshcaller_role(agent),
                type: 'roles'
              }]
            }
          },
          role: deduct_freshcaller_role(agent),
          type: 'users'
        }
      }
    end

    def add_agent_to_freshcaller(agent)
      freshcaller_request(add_agent_params(agent), freshcaller_add_agent_url, :post, email: ::User.current.email)
    end

    def deduct_freshcaller_role(agent)
      deducted_role = FRESHCALLER_ROLE_PRIVILEGES.detect do |k, v|
        agent.user.privilege? v
      end.try(:first)
      deducted_role || :agent
    end

    def fc_error?(response)
      response['error_code'].present?
    end

    def fc_agent_limit?(result)
      return unless result.key?('errors')

      result['errors'].any? do |kv|
        kv['detail'].include?('Please purchase extra to add new agents')
      end
    end

    def fc_agent_already_present?(agent, result)
      return if agent.freshcaller_agent.try(:fc_user_id).present?

      return unless result.key?('errors')

      result['errors'].any? do |kv|
        kv['detail'].include?('has already been taken')
      end
    end

    def fc_agent_created?(result)
      [200, 201].include?(result.code)
    end

    def create_freshcaller_agent(agent, result)
      if agent.freshcaller_agent.present?
        agent.freshcaller_agent.update_attributes(fc_enabled: true, fc_user_id: result.try(:[], 'data').try(:[], 'id'))
      else
        agent.create_freshcaller_agent(
          fc_enabled: true,
          fc_user_id: result.try(:[], 'data').try(:[], 'id')
        )
      end
    end
  end
end
