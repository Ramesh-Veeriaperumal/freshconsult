# Query/Filter generation helpers
# Can be reused for fetching documents too
module Search::Filters::QueryHelper
  extend ActiveSupport::Concern

    COLUMN_MAPPING = {
      #_Note_: From WF filters => ES field
      'helpdesk_schema_less_tickets.boolean_tc02' =>  'trashed',
      'users.customer_id'                         =>  'company_id',
      'helpdesk_tags.id'                          =>  'tag_ids',
      'helpdesk_tags.name'                        =>  'tag_names',
      'helpdesk_subscriptions.user_id'            =>  'watchers'
    }

    private

    ######### Cases implemented ########
    # responder_id  : terms with hack  #
    # group_id      : terms with hack  #
    # created_at    : range            #
    # due_by        : range            #
    # rest          : terms            #
    ####################################

    def es_query(conditions, neg_conditions)

      condition_block = {
        :should   => [],
        :must     => [],
        :must_not => []
      }

      # Hack for handling permissible as used in tickets
      condition_block[:must].push(permissible_filter) if (User.current.agent? and User.current.restricted?)

      construct_conditions(condition_block[:must], conditions)
      construct_conditions(condition_block[:must_not], neg_conditions)

      filtered_query(nil, bool_filter(condition_block))
    end

    def permissible_filter
      ({
        :group_tickets      =>  bool_filter(:should => [
                                                        group_id_es_filter('group_id', ['0']), 
                                                        term_filter('responder_id', [User.current.id.to_s]), 
                                                        term_filter('requester_id', [User.current.id.to_s])
                                                        ]),
        :assigned_tickets   =>  term_filter('responder_id', [User.current.id.to_s])
      })[Agent::PERMISSION_TOKENS_BY_KEY[User.current.agent.ticket_permission]]
    end

    # Loop and construct ES conditions from WF filter conditions
    def construct_conditions(es_wrapper, wf_conditions)
      wf_conditions.each do |field|
        # Doing gsub as flexifields are flat now.
        cond_field = (COLUMN_MAPPING[field['condition']].presence || field['condition'].to_s).gsub('flexifields.','')

        es_wrapper.push(handle_field(cond_field, 
                                        field['value'].to_s.split(','))) if cond_field.present?
      end
    end

    # For handling responder with hacks
    def responder_id_es_filter(field_name, values)
      if values.include?('0')
        values.delete('0')
        values.push(User.current.id.to_s)
      end

      missing_es_filter(field_name, values)
    end

    # For handling group with hacks
    def group_id_es_filter(field_name, values)
      if values.include?('0')
        values.delete('0')
        values.concat(User.current.agent_groups.select(:group_id).map(&:group_id).map(&:to_s))
      end

      missing_es_filter(field_name, values)
    end

    # Handle conditions with null queries
    def missing_es_filter(field_name, values)
      if values.include?('-1')
        values.delete('-1')
        bool_filter(:should => [
          missing_filter(field_name), 
          terms_filter(field_name, values.uniq)
        ])
      else
        terms_filter(field_name, values.uniq)
      end
    end

    # Needed this to handle '0' case
    def watchers_es_filter(field_name, values)
      responder_id_es_filter(field_name, values)
    end

    # Only one value can be chosen
    def created_at_es_filter(field_name, value)
      value = value.first #=> One value in array as we do .split
      filter_cond = Hash.new
      
      Time.use_zone(Account.current.time_zone) do
        case value
        when 'today'
          filter_cond.update(:gt => Time.zone.now.beginning_of_day.utc.iso8601)
        when 'yesterday'
          filter_cond.update(:gt => Time.zone.now.yesterday.beginning_of_day.utc.iso8601, 
                              :lt => Time.zone.now.beginning_of_day.utc.iso8601)
        when 'week'
          filter_cond.update(:gt => Time.zone.now.beginning_of_week.utc.iso8601)
        when 'last_week'
          filter_cond.update(:gt => Time.zone.now.beginning_of_day.ago(7.days).utc.iso8601)
        when 'month'
          filter_cond.update(:gt => Time.zone.now.beginning_of_month.utc.iso8601)
        when 'last_month'
          filter_cond.update(:gt => Time.zone.now.beginning_of_day.ago(1.month).utc.iso8601)
        when 'two_months'
          filter_cond.update(:gt => Time.zone.now.beginning_of_day.ago(2.months).utc.iso8601)
        when 'six_months'
          filter_cond.update(:gt => Time.zone.now.beginning_of_day.ago(6.months).utc.iso8601)
        else
          if value.to_s.is_number?
            filter_cond.update(:gt => Time.zone.now.ago(value.to_i.minutes).utc.iso8601)
          else
            start_date, end_date = value.split('-')
            filter_cond.update(:gte => Time.zone.parse(start_date).utc.iso8601, 
                                :lte => Time.zone.parse(end_date).end_of_day.utc.iso8601)
          end
        end
        range_filter(field_name, filter_cond)
      end
    end

    # Multiple values can be chosen
    def due_by_es_filter(field_name, values)
      filter_cond = Array.new

      Time.use_zone(Account.current.time_zone) do
        values.each do |value|
          case value.to_i
          # Overdue
          when TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:all_due]
            filter_cond.push(range_filter(field_name, :lte => Time.zone.now.utc.iso8601))
          # Today
          when TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:due_today]
            filter_cond.push(range_filter(field_name, 
                                          :gte => Time.zone.now.beginning_of_day.utc.iso8601, 
                                          :lte => Time.zone.now.end_of_day.utc.iso8601))
          # Tomorrow
          when TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:due_tomo]
            filter_cond.push(range_filter(field_name, 
                                          :gte => Time.zone.now.tomorrow.beginning_of_day.utc.iso8601, 
                                          :lte => Time.zone.now.tomorrow.end_of_day.utc.iso8601))
          # Next 8 hours
          when TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:due_next_eight]
            filter_cond.push(range_filter(field_name, 
                                          :gte => Time.zone.now.utc.iso8601, 
                                          :lte => 8.hours.from_now.utc.iso8601))
          end
        end
        bool_filter(:should => filter_cond, :must => ticket_status_conditions)
      end
    end

    # Appended in due-by container
    # So adding the same here to reflect similarity
    def ticket_status_conditions
      [
        term_filter('status_stop_sla_timer', false),
        term_filter('status_deleted', false)
      ]
    end

    # For generically handling other fields
    def handle_field(field_name, values)
      send("#{field_name}_es_filter", field_name, values) rescue terms_filter(field_name, values)
    end

    ### ES METHODS ###

    # Cache default: false
    def bool_filter(cond_block)
      { :bool => cond_block }
    end

    # Cache: always true
    def missing_filter(field_name)
      { :missing => { :field => field_name.to_s }}
    end

    # Default execution mode: Index
    # Cache default(index execution): true
    def range_filter(field_name, value_with_op)
      { :range => { field_name.to_s =>  value_with_op, :_cache => false }}
    end

    # Cache default: true
    def terms_filter(field_name, values) 
      { :terms => { field_name.to_s => values, :_cache => false }}
    end

    # Cache default: true
    def term_filter(field_name, value)
      { :term => { field_name.to_s => value, :_cache => false }}
    end

    def filtered_query(query_part={}, filter_part={})
      base = ({:query => { :filtered => {}}})
      
      base[:query][:filtered].update(:query => query_part) if query_part.present?
      base[:query][:filtered].update(:filter => filter_part) if filter_part.present?

      base
    end

end