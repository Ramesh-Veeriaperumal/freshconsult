# frozen_string_literal: true

module Channel::V2::SubscriptionConstants
  UPDATE_FIELDS = (AdminSubscriptionConstants::UPDATE_FIELDS + [:addons]).freeze
end
