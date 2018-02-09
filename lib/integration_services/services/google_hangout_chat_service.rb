module IntegrationServices::Services
  class GoogleHangoutChatService < IntegrationServices::Service
    include ChannelIntegrations::Utils::Schema
    include ChannelIntegrations::Constants

    def receive_add_chat
      post_command_to_central 'install_app'
    rescue => e
      Rails.logger.error "Error in receive_add_hanogut_chat: #{e}"
    end

    def receive_remove_chat
      post_command_to_central 'uninstall_app'
    rescue => e
      Rails.logger.error "Error in receive_hangout_chat: #{e}"
    end

    private

    def post_command_to_central(command)
      payload_hash = command_payload(command)
      msg_id = generate_msg_id(payload_hash)
      Rails.logger.info "Command from Hangouts Chat, Command: #{command}, Msg_id: #{msg_id}"
      Channel::CommandWorker.perform_async({payload: payload_hash}, msg_id)
    end

    def command_payload(command_name)
      schema = default_command_schema('google-hangout-chat', command_name)
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

    def generate_msg_id(payload)
      Digest::MD5.hexdigest(payload.to_s)
    end
  end
end
