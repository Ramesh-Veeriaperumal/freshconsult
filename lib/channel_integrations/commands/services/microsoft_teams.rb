module ChannelIntegrations::Commands::Services
  class MicrosoftTeams
    include ChannelIntegrations::Utils::ActionParser
    include ChannelIntegrations::Constants
    include ChannelIntegrations::CommonActions::Note

    def receive_update_agents_list(payload)
      data = payload[:data]

      active_users_key = get_redis_key(:active_users, payload[:account_id])
      authorized_users_key = get_redis_key(:authorized_users, payload[:account_id])
      update_redis_keys(active_users_key, data[:active_agent_ids])
      update_redis_keys(authorized_users_key, data[:authorized_agent_ids])

      default_success_format
    rescue => e
      construct_error_message("Error in updating agents list, #{e.message}")
    end

    def receive_create_note(payload)
      create_note(payload)
    rescue => e
      construct_error_message("Error in Creating note, #{e.message}")
    end

    def receive_create_reply(payload)
      create_reply(payload)
    rescue => e
      construct_error_message("Error in Creating reply, #{e.message}")
    end

    private

      def get_redis_key(key_name, account_id)
        INTEGRATIONS_REDIS_INFO[:template] % {
          owner: OWNERS_LIST[:microsoft_teams],
          account_id: account_id,
          key: INTEGRATIONS_REDIS_INFO[:general_keys][key_name]
        }
      end

      def update_redis_keys(key, agent_ids)
        # removing the key completely and creating a new one with new list.
        $redis_integrations.perform_redis_op('del', key)
        $redis_integrations.perform_redis_op('sadd', key, agent_ids)
      end

      def construct_error_message(message)
        error = default_error_format
        error[:data] = { message: message }
        error
      end
  end
end
