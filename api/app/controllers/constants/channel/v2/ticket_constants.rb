module Channel::V2::TicketConstants
  DISPLAY_ID_FIELD = %w(display_id).freeze
  IMPORT_ID_FIELD = %w(import_id).freeze
  PARENT_ID_FIELD = %w(parent_id).freeze
  SOCIAL_ATTRIBUTES = %w(source_additional_info).freeze
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

  # SYNC ACTION
  SYNC_ATTRIBUTE_ASSOCIATION_MAPPING = [
    [:display_ids, 'display_id', 'helpdesk_tickets'],
    [:created_at, 'created_at', 'helpdesk_tickets'],
    [:updated_at, 'updated_at', 'helpdesk_tickets'],
    [:closed_at, 'closed_at', 'helpdesk_ticket_states'],
    [:resolved_at, 'resolved_at', 'helpdesk_ticket_states']
  ].freeze
  SYNC_ATTRIBUTE_MAPPING = Hash[*SYNC_ATTRIBUTE_ASSOCIATION_MAPPING.map { |i| [i[0], i[1]] }.flatten]
  SYNC_ASSOCIATION_MAPPING = Hash[*SYNC_ATTRIBUTE_ASSOCIATION_MAPPING.map { |i| [i[0], i[2]] }.flatten]
  LOAD_OBJECT_EXCEPT = ['sync'].freeze
  SYNC_FILTER_ATTRIBUTES = %w[display_ids created_at updated_at resolved_at closed_at].freeze
  SYNC_DATETIME_ATTRIBUTES = %i[created_at updated_at resolved_at closed_at].freeze
  SYNC_TICKET_STATE_ATTRIBUTES = %w[resolved_at closed_at].freeze
  SYNC_FIELDS = (%w[meta primary_key_offset] + SYNC_FILTER_ATTRIBUTES) .freeze
  SYNC_ID_FIELDS = %i[display_ids].freeze
end
