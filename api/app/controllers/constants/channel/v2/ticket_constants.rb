module Channel::V2::TicketConstants
  DISPLAY_ID_FIELD = %w(display_id).freeze
  IMPORT_ID_FIELD = %w(import_id).freeze
  PARENT_ID_FIELD = %w(parent_id).freeze
  SOCIAL_ATTRIBUTES = %w(source_additional_info channel_id channel_profile_unique_id channel_message_id).freeze
  TICKET_ATTRIBUTES = (%w(deleted spam created_at updated_at) + 
                        DISPLAY_ID_FIELD + IMPORT_ID_FIELD).freeze
  TICKET_STATES_ATTRIBUTES = %w(opened_at pending_since resolved_at closed_at
                                first_assigned_at assigned_at first_response_time
                                requester_responded_at agent_responded_at
                                status_updated_at sla_timer_stopped_at
                                avg_response_time_by_bhrs on_state_time resolution_time_by_bhrs
                                inbound_count outbound_count group_escalated
                                first_resp_time_by_bhrs avg_response_time
                                resolution_time_updated_at).freeze

  ASSOCIATE_ATTRIBUTES = (TICKET_STATES_ATTRIBUTES + 
                          DISPLAY_ID_FIELD + 
                          IMPORT_ID_FIELD).map(&:to_sym).freeze
  CONDITIONAL_ATTRIBUTES = %i(display_id import_id on_state_time).freeze
  ACCESSIBLE_ATTRIBUTES = (ASSOCIATE_ATTRIBUTES - CONDITIONAL_ATTRIBUTES).freeze

  CREATE_FIELDS = (ApiTicketConstants::CREATE_FIELDS +
                   TICKET_ATTRIBUTES +
                   TICKET_STATES_ATTRIBUTES + SOCIAL_ATTRIBUTES).freeze
  UPDATE_FIELDS = (ApiTicketConstants::UPDATE_FIELDS +
                   TICKET_ATTRIBUTES + PARENT_ID_FIELD +
                   TICKET_STATES_ATTRIBUTES).freeze

  DATETIME_ATTRIBUTES = %i(opened_at pending_since resolved_at closed_at first_assigned_at
                           assigned_at first_response_time requester_responded_at agent_responded_at
                           status_updated_at sla_timer_stopped_at)
  FB_MSG_TYPES = ['dm', 'post', 'ad_post'].freeze # Dont change the index of the value
  TWITTER_MSG_TYPES = ['dm', 'mention'].freeze
end
