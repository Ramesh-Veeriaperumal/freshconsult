module ChannelIntegrations::Constants
  SUCCESS = true
  FAILURE = false

  # List of services under the Channel Framework.
  OWNERS_LIST = {
    microsoft_teams: 'MSTEAMS',
    twitter: 'twitter'
  }.freeze

  # The owner name received from the Kafka and their corresponding service class names.
  SERVICE_NAME_CLASS_MAPPING = {
    'microsoft-teams': 'MicrosoftTeams',
    'twitter': 'Twitter',
    'shopify': 'Shopify'
  }.freeze

  # The module names for the Command/replies.
  SERVICE_MODULES = {
    command: 'ChannelIntegrations::Commands::Services',
    reply: 'ChannelIntegrations::Replies::Services'
  }.freeze

  # Generalized redis keys for the Profile page regarding integrations using channel Framework.
  INTEGRATIONS_REDIS_INFO = {
    template: '%{owner}:%{key}:%{account_id}',
    general_keys: {
      active_users: 'ACTIVE_USERS',
      authorized_users: 'AUTHORIZED_USERS'
    },
    auth_waiting_key: 'AGENT_AUTH_BEING_PROCESSED'
  }.freeze

  DEDUP_REDIS_KEY = 'CHANNEL_FRAMEWORK:DEDUP:%<msg_id>s'.freeze

  # Default commands that the channel framework can respond to
  DEFAULT_ACTIONS_VALUE_MAP = {
    create_note: 'create_note',
    create_ticket: 'create_ticket',
    create_reply: 'create_reply',
    update_key: 'update_key'
  }.freeze


  REPLY_MESSAGES = {
    invalid_action: "Couldn't find proper action",
    default_error_message: 'Something went wrong while processing the request'
  }.freeze

  PAYLOAD_TYPES = {
    command_to_channel: 'channel_framework_command', # Command sent from helpkit to channel.
    command_to_helpkit: 'helpkit_command', # Command sent from Channel to helpkit.
    reply_from_channel: 'channel_framework_reply', # Reply sent for channel_framework_command (Channel to helpkit).
    reply_from_helpkit: 'helpkit_reply', # Reply sent for helpkit_command (helpkit to channel).
  }.freeze

  INCOMING_PAYLOAD_TYPES = [
    PAYLOAD_TYPES[:command_to_helpkit],
    PAYLOAD_TYPES[:reply_from_channel]
  ].freeze

  COMMON_COMMANDS_MODULES_MAPPING = {
    create_ticket: 'ChannelIntegrations::CommonActions::Ticket',
    create_note: 'ChannelIntegrations::CommonActions::Note'
  }.freeze
end
