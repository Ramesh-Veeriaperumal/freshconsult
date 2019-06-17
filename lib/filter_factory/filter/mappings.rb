module FilterFactory::Filter
  module Mappings
    TICKETANALYTICS_COLUMN_MAPPING = {
      'helpdesk_schema_less_tickets.boolean_tc02' =>  'trashed',
      'owner_id'                                  =>  'company_id',
      'helpdesk_tags.id'                          =>  'tag_ids',
      'helpdesk_tags.name'                        =>  'tag',
      'helpdesk_subscriptions.user_id'            =>  'watchers',
      'helpdesk_schema_less_tickets.product_id'   =>  'product_id',
      'ticket_type'                               =>  'type',
      'helpdesk_ticket_statuses.deleted'          =>  'status_deleted',
      'helpdesk_ticket_statuses.stop_sla_timer'   =>  'status_stop_sla_timer',
      'helpdesk_tickets.display_id'               =>  'display_id'
    }.freeze

    FLEXIFIELDS_JOIN = ['INNER JOIN flexifields ON flexifields.flexifield_set_id = helpdesk_tickets.id and flexifields.account_id = helpdesk_tickets.account_id '].freeze

    TICKETANALYTICS_ORDER_MAPPINGS = {
      requester_responded_at: :ticket_states,
      agent_responded_at: :ticket_states,
      fsm_appointment_start_time: FLEXIFIELDS_JOIN
    }.freeze

    def flexifields_order_by(order_by, order_type)
      ff_column_name = fsm_appointment_start_time_ff_column_name
      "flexifields.#{ff_column_name} #{order_type.upcase}"
    end

    TICKETANALYTICS_ORDER_BY_MAPPINGS = {
      fsm_appointment_start_time: 'flexifields_order_by'
    }.freeze

    TICKETANALYTICS_TEXT_FIELDS = ['type', 'tag'].freeze
    TICKETANALYTICS_ID_FIELDS = ['company_id', 'tag_ids', 'watchers', 'product_id', 'responder_id', 'requester_id', 'internal_agent_id',
                                 'status', 'source', 'display_id', 'group_id', 'internal_group_id', 'priority', 'parent_ticket_id',
                                 'sl_skill_id', 'association_type'].freeze
  end
end
