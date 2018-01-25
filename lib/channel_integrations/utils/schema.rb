module ChannelIntegrations::Utils
  module Schema
    def default_command_schema(client, command)
      default_schema.merge!(owner: 'helpkit',
                            client: client,
                            command_name: command,
                            command_id: SecureRandom.uuid)
    end

    # Owner - who called the command.
    # Original_payload is the args[:payload] received.
    def default_reply_schema(owner, command, original_payload)
      default_schema.merge!(owner: owner,
                            client: 'helpkit',
                            command_name: command,
                            command_id: original_payload[:command_id], # returning the original command_id to track the msg.
                            reply_id: SecureRandom.uuid,
                            context: original_payload[:context])
    end

    def default_schema
      {
        schema_version: ChannelFrameworkConfig['schema_version'],
        epoc_time: Time.now.to_i, # To create a new MD5 hash everytime(as others are constant).
        account_id: Account.current.id,
        domain: Account.current.full_url,
        tenant: ChannelFrameworkConfig['tenant'],
        region: ChannelFrameworkConfig['region']
      }
    end
  end
end
