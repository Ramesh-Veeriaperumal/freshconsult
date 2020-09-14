class QueryHash
  attr_accessor :query_hash, :format
  REMOVE_FFNAME_FOR = %w(spam deleted).freeze

  SPAM_CONDITION = { 'condition' => 'spam', 'operator' => 'is', 'value' => false }.freeze
  DELETED_CONDITION = { 'condition' => 'deleted', 'operator' => 'is', 'value' => false }.freeze
  ARRAY_VALUED_OPERATORS = ['is_in', 'due_by_op'].freeze
  TICKET_FIELD_DATA = 'ticket_field_data.'.freeze
  FLEXIFIELDS = 'flexifields.'.freeze

  def initialize(params, other_options = {})
    @query_hash = params
    @ff_entries_cached = other_options[:ff_entries]
  end

  def to_system_format
    @format = :system
    @to_system_format ||= transform
  end

  def to_json
    @format = :presentable
    @to_json ||= transform
  end

  private

    def transform
      result = query_hash.dup.select { |q| !deleted_custom_field_or_spam?(q) }.map { |q| transform_query(q) }
      result += (format == :system ? spam_deleted_conditions : [])
    end

    def transform_query(query)
      result = query.slice('condition', 'operator', 'ff_name', 'value', 'type')
      result = (format == :system ? result.except('type') : result.except('ff_name'))
      result['value'] = transform_value(query)
      return result if skip_transform?(query)
      result.merge!(transform_condition(query))
      if format == :presentable
        result['type'] = custom_field?(query) ? 'custom_field' : 'default'
      end
      result
    end

    def skip_transform?(query)
      ((format == :presentable) && query.key?('type')) ||
        ((format == :system) && !query.key?('type')) ||
        (!query.key?('type') && !query.key?('ff_name'))
    end

    def transform_value(query)
      val = query['value']
      return formatted_created_at(query) if date_time_field?(query)
      if format.eql?(:system)
        if Account.current.wf_comma_filter_fix_enabled?
          val
        else
          val.is_a?(Array) ? val.join(',') : val
        end
      else
        return val unless ARRAY_VALUED_OPERATORS.include?(query['operator'])
        val.is_a?(String) ? val.split(',') : (val.is_a?(Array) ? val : [val])
      end
    end

    def transform_condition(query)
      if format.eql?(:system)
        condition_to_system_format(query)
      else
        { 'condition' => (custom_field?(query) ? ff_field_alias(query) : sanitize_condition_param(query['condition'], true)) }
      end
    end

    def sanitize_condition_param(condition, reverse_lookup=false)
      (reverse_lookup ? TicketFilterConstants::RENAME_CONDITIONS.key(condition) : TicketFilterConstants::RENAME_CONDITIONS[condition]) || condition
    end

    def condition_to_system_format(query)
      return {} if REMOVE_FFNAME_FOR.include?(query['condition'])
      condition = { 'ff_name' => 'default', 'condition' => sanitize_condition_param(query['condition']) }
      if query['type'] == 'custom_field'
        ff_name = "#{query['condition']}_#{Account.current.id}"
        ff_table_name = Helpdesk::Filters::CustomTicketFilter.custom_field_table_name
        condition = { 'condition' => "#{ff_table_name}.#{ff_alias_name_map[ff_name]}", 'ff_name' => ff_name }
      end
      condition
    end

    def custom_field?(query)
      return false if query['ff_name'] == 'default'

      query['condition'].include?(FLEXIFIELDS) || query['condition'].include?(TICKET_FIELD_DATA)
    end

    def ff_field_alias(query)
      TicketDecorator.display_name(get_ff_field_name_from_query(query))
    end

    def date_time_field?(query)
      if Account.current.field_service_management_enabled? # can be replaced with Account.current.custom_date_time_fields_from_cache.present? when we support filter for all custom date time fields
        fsm_date_time_fields = TicketFilterConstants::FSM_DATE_TIME_FIELDS.collect { |x| x + "_#{Account.current.id}" }
        (query['condition'] == 'created_at' && query['operator'] == 'is_greater_than') || TicketFilterConstants::FSM_DATE_TIME_FIELDS.include?(query['condition']) || fsm_date_time_fields.include?(query['ff_name'])
      # elsif Account.current.custom_date_fields_from_cache.present?
      else
        query['condition'] == 'created_at' && query['operator'] == 'is_greater_than'
      end
    end

    def formatted_created_at(query)
      if format == :system
        query['value'].is_a?(Hash) ? format_date_time(query) : query['value']
      else
        return query['value'] unless query['value'].include?(' - ')

        from, to = query['value'].split(' - ')
        {
          'from' => format_time(from),
          'to' => format_time(to)
        }
      end
    end

    def format_date_time(query)
      if query['condition'] == 'created_at'
        [format_time(query['value']['from']), format_time(query['value']['to'])].join(' - ')
      else
        [iso_time_format(query['value']['from']), iso_time_format(query['value']['to'])].join(' - ')
      end
    end

    def format_time(time)
      time = Time.zone.parse(time)
      format.eql?(:system) ? time.strftime('%d %b %Y %T') : time.iso8601
    end

    def iso_time_format(time)
      Time.zone.parse(time.to_s).try(:iso8601)
    end

    def get_ff_field_name_from_query(query)
      name = query['ff_name']
      unless name.present?
        ff_name = query['condition'].gsub('flexifields.', '')
        name = ff_name_alias_map[ff_name]
      end
      name
    end

    def spam_deleted_conditions
      [SPAM_CONDITION, DELETED_CONDITION]
    end

    def deleted_custom_field_or_spam?(query)
      return true if REMOVE_FFNAME_FOR.include?(query['condition'])
      if format == :system && query['type'] == 'custom_field'
        ff_alias_name_map["#{query['condition']}_#{Account.current.id}"].nil?
      elsif format == :presentable && custom_field?(query)
        ff_alias_name_map[get_ff_field_name_from_query(query)].nil?
      else
        false
      end
    end

    def all_ff_fields
      @all_ff_fields ||= @ff_entries_cached || Account.current.flexifield_def_entries.select([:flexifield_alias, :flexifield_name]).map(&:attributes)
    end

    def ff_alias_name_map
      @alias_name_map ||= Hash[all_ff_fields.map { |fields| [fields['flexifield_alias'], fields['flexifield_name']] }]
    end

    def ff_name_alias_map
      @name_alias_map ||= Hash[all_ff_fields.map { |fields| [fields['flexifield_name'], fields['flexifield_alias']] }]
    end
end
