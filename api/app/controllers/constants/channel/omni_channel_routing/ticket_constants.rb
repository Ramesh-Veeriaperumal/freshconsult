module Channel::OmniChannelRouting::TicketConstants
  ASSIGN_FIELDS = [:agent_id, current_state: [:group_id]].freeze
  VALIDATION_CLASS = 'Channel::OmniChannelRouting::TicketValidation'.freeze
  DELEGATOR_CLASS = 'Channel::OmniChannelRouting::TicketDelegator'.freeze
end.freeze
