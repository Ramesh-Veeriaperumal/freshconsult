class TicketFieldDecorator < SimpleDelegator
  class << self 
    def get_ticket_field_choices(tf)
      @choices = tf.field_type == 'nested_field' ? nested_choices(tf) : ticket_field_choices(tf)
    end

    def default_requester_field(tf)
      tf.field_type == "default_requester"
    end

    def portal_cc(tf)
      tf.field_options.try(:[], 'portalcc')
    end

    def portalcc_to(tf)
      tf.field_options.try(:[], 'portalcc_to')
    end

    private
      def ticket_field_choices(tf)
        case tf.field_type
        when 'custom_dropdown'
          tf.picklist_values.collect(&:value)
        when 'default_priority'
          Hash[TicketConstants.priority_names]
        when 'default_source'
          Hash[TicketConstants.source_names]
        when 'default_status'
          api_statuses = Helpdesk::TicketStatus.status_objects_from_cache(Account.current).map do|status|
            [
              status.status_id, [Helpdesk::TicketStatus.translate_status_name(status, 'name'),
                                 Helpdesk::TicketStatus.translate_status_name(status, 'customer_display_name')]
            ]
          end
          Hash[api_statuses]
        when 'default_ticket_type'
          Account.current.ticket_types_from_cache.collect(&:value)
        when 'default_agent'
          return Hash[Account.current.agents_from_cache.collect { |c| [c.user.name, c.user.id] }]
        when 'default_group'
          Hash[Account.current.groups_from_cache.collect { |c| [CGI.escapeHTML(c.name), c.id] }]
        when 'default_product'
          Hash[Account.current.products_from_cache.collect { |e| [CGI.escapeHTML(e.name), e.id] }]
        else
          []
        end
      end

      def nested_choices(tf)
        tf.picklist_values.collect do |c|
          Hash[c.value, c.sub_picklist_values.collect do |x|
            Hash[x.value, x.sub_picklist_values.collect(&:value)]
          end]
        end
      end
  end
end