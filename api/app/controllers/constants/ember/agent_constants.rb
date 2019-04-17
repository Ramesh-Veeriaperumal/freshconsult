module Ember::AgentConstants
  include ::AgentConstants
  PRIVATE_UPDATE_FIELDS = [:freshchat_token, :avatar_id].freeze
  UPDATE_FIELDS = UPDATE_FIELDS | PRIVATE_UPDATE_FIELDS
  DELEGATOR_CLASS = 'AgentDelegator'.freeze
  VALIDATION_CLASS = 'AgentValidation'.freeze
end
