module Ember::AgentConstants
  include ::AgentConstants
  PRIVATE_UPDATE_FIELDS = [:freshchat_token, :avatar_id, :skill_ids].freeze
  UPDATE_FIELDS = UPDATE_FIELDS | PRIVATE_UPDATE_FIELDS | [:contact].freeze
  DELEGATOR_CLASS = 'AgentDelegator'.freeze
  VALIDATION_CLASS = 'AgentValidation'.freeze
end
