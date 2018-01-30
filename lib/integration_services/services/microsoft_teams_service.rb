module IntegrationServices::Services
  class MicrosoftTeamsService < IntegrationServices::Service
    include ChannelIntegrations::Utils::Schema
    include ChannelIntegrations::Constants

    def receive_authorize_agent
      create_auth_redis_key
      post_command_to_central 'authorize_agent', @payload
    rescue => e
      Rails.logger.error "Error in receive_add_teams: #{e}"
    end

    def receive_add_teams
      create_redis_keys
      post_command_to_central 'install_app'
    rescue => e
      Rails.logger.error "Error in receive_add_teams: #{e}"
    end

    def receive_remove_teams
      destroy_redis_keys
      post_command_to_central 'uninstall_app'
    rescue => e
      Rails.logger.error "Error in receive_remove_teams: #{e}"
    end

    private

      def owner_name
        OWNERS_LIST[:microsoft_teams]
      end

      def post_command_to_central(command, payload = nil)
        payload_hash = command_payload(command, payload)
        msg_id = generate_msg_id(payload_hash)
        Rails.logger.info "Command from Microsoft teams, Command: #{command}, Msg_id: #{msg_id}"
        Channel::CommandWorker.perform_async({ payload: payload_hash }, msg_id)
      end

      def create_redis_keys
        INTEGRATIONS_REDIS_INFO[:general_keys].each do |_key, value|
          key = INTEGRATIONS_REDIS_INFO[:template] % { owner: owner_name, key: value, account_id: Account.current.id }
          $redis_integrations.perform_redis_op('sadd', key, [])
        end
        create_auth_redis_key
      end

      def create_auth_redis_key # To Give a 10 sec interval to get the response back from central.
        key = INTEGRATIONS_REDIS_INFO[:template] % { owner: owner_name, key: INTEGRATIONS_REDIS_INFO[:auth_waiting_key], account_id: Account.current.id }
        expiry_time = ChannelFrameworkConfig['hop_interval'] ? ChannelFrameworkConfig['hop_interval'].to_i.seconds : 10.seconds
        $redis_integrations.perform_redis_op('setex', key, expiry_time, true)
      end

      def destroy_redis_keys
        INTEGRATIONS_REDIS_INFO[:general_keys].each do |_key, value|
          key = INTEGRATIONS_REDIS_INFO[:template] % { owner: owner_name, key: value, account_id: Account.current.id }
          $redis_integrations.del(key)
        end
      end

      def generate_msg_id(payload)
        Digest::MD5.hexdigest(payload.to_s)
      end

      def command_payload(command_name, payload = nil)
        schema = default_command_schema('microsoft-teams', command_name)
        schema.merge!(send("#{command_name}_payload", payload))
      end

      def install_app_payload(_payload = nil)
        {
          data:
          {
            agentsList: Account.current.technicians.map do |agent|
              {
                id: agent.id,
                name: agent.name,
                email: agent.email
              }
            end,
            tenant_id: @installed_app.configs_tenant_id,
            app_configs: @installed_app.configs
          },
          context: {}
        }
      end

      def uninstall_app_payload(_payload = nil)
        {
          data: {},
          context: {}
        }
      end

      def authorize_agent_payload(payload = nil)
        {
          data:
          {
            agentDetails: {
              id: User.current.id,
              name: User.current.name,
              email: User.current.email,
              microsoft_user_id: payload['user_id'],
              app_configs: payload
            },
            tenant_id: payload['tenant_id']
          },
          context: {}
        }
      end
  end
end
