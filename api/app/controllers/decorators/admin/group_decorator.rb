# frozen_string_literal: true

module Admin
  class GroupDecorator < ::GroupDecorator
    def initialize(record, options)
      super(record, options)
    end

    def to_group_v2_hash
      result = to_full_hash.except(:auto_ticket_assign)
      result.keys.each { |k| result[KEY_MAPPINGS[k]] = result.delete(k) if KEY_MAPPINGS[k] }
      result.merge!(
        allow_agents_to_change_availability: allow_agents_to_change_availability,
        automatic_agent_assignment: automatic_assignment_hash(record.ticket_assign_type)
      )
      result
    end

    private

      def automatic_assignment_hash(ticket_assign_type)
        case ticket_assign_type
        when NO_ASSIGNMENT
          { enabled: false }
        when Group::TICKET_ASSIGN_TYPE[:load_based_omni_channel_assignment]
          { enabled: true, type: OMNI_CHANNEL }
        else
          settings = []
          result = { enabled: true, type: CHANNEL_SPECIFIC }
          settings << ticket_settings_hash(ticket_assign_type, (record.capping_limit || 0))
          result.merge!(settings: settings)
          result
        end
      end

      def ticket_settings_hash(ticket_assign_type, capping_limit)
        result = { channel: CHANNEL_NAMES[:freshdesk], assignment_type: get_assignment_type(ticket_assign_type, capping_limit) }
        result.merge!(assignment_type_settings: { capping_limit: capping_limit }) if capping_limit_required?(ticket_assign_type, capping_limit)
        result
      end

      def get_assignment_type(ticket_assign_type, capping_limit)
        case ticket_assign_type
        when ROUND_ROBIN # rr & lbrr
          capping_limit.zero? ? ASSIGNMENT_TYPE_MAPPINGS[ROUND_ROBIN] : ASSIGNMENT_TYPE_MAPPINGS[LOAD_BASED_ROUND_ROBIN]
        when LBRR_BY_OMNIROUTE
          ASSIGNMENT_TYPE_MAPPINGS[LBRR_BY_OMNIROUTE]
        when Group::TICKET_ASSIGN_TYPE[:skill_based]
          ASSIGNMENT_TYPE_MAPPINGS[SKILL_BASED_ROUND_ROBIN]
        else
          # type code here
        end
      end

      def capping_limit_required?(ticket_assign_type, capping_limit)
        capping_limit.positive? && [Group::TICKET_ASSIGN_TYPE[:round_robin], Group::TICKET_ASSIGN_TYPE[:skill_based]].include?(ticket_assign_type)
      end
  end
end
