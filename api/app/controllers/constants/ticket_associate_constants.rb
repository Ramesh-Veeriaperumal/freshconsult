module TicketAssociateConstants
  # ControllerConstants
  BULK_LINK_FIELDS = %w(tracker_id).freeze
  VALIDATION_CLASS = 'TicketAssociateValidation'.freeze
  DELEGATOR_CLASS = 'TicketAssociatesDelegator'.freeze
  TRACKER_DELEGATOR_CLASS = 'BulkLinkTrackerDelegator'.freeze
end.freeze
