class QueryHash

  attr_accessor :query_hash, :format
  REMOVE_FFNAME_FOR = %w(spam deleted).freeze

  SPAM_CONDITION = { 'condition' => 'spam', 'operator' => 'is', 'value' => false }
  DELETED_CONDITION = { 'condition' => 'deleted', 'operator' => 'is', 'value' => false }

  def initialize(params)
    @query_hash = params
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
      result +=  (format == :system ? spam_deleted_conditions : [])
    end

    def transform_query(query)
      result = query.slice('condition', 'operator', 'ff_name', 'value', 'type')
      result = (format == :system ? result.except('type') : result.except('ff_name'))
      result['value'] = transform_value(query)
      return result if skip_transform?(query)
      result.merge!(transform_condition(query))
      if format == :presentable
        result['type'] = is_flexi_field?(query) ? 'custom_field' : 'default'
      end
      result
    end

    def skip_transform?(query)
      ((format == :presentable) && query.has_key?("type")) ||
        ((format == :system) && !query.has_key?("type")) || 
        (!query.has_key?("type") && !query.has_key?("ff_name"))
    end

    def transform_value(query)
      val = query['value']
      return formatted_created_at(query) if is_created_at?(query)
      if format.eql?(:system)
        val.is_a?(Array) ? val.join(',') : val
      else
        return val unless query['operator'] == 'is_in'
        val.is_a?(String) ? val.split(',') : (val.is_a?(Array) ? val : [val])
      end
    end

    def transform_condition(query)
      if format.eql?(:system)
        condition_to_system_format(query)
      else
        { 'condition' => (is_flexi_field?(query) ? ff_field_alias(query) : query['condition']) }
      end
    end

    def condition_to_system_format(query)
      return {} if REMOVE_FFNAME_FOR.include?(query['condition'])
      condition = { 'ff_name' => 'default' }
      if query['type'] == 'custom_field'
        ff_name = "#{query['condition']}_#{Account.current.id}"
        condition = { 'condition' => "flexifields.#{ff_alias_name_map[ff_name]}", 'ff_name' => ff_name }
      end
      condition
    end

    def is_flexi_field?(query)
      query['ff_name'] != 'default' && query['condition'].include?('flexifields.')
    end

    def ff_field_alias(query)
      TicketDecorator.display_name(get_ff_field_name_from_query(query))
    end

    def is_created_at?(query)
      query['condition'] == 'created_at' && query['operator'] == 'is_greater_than'
    end

    def formatted_created_at(query)
      if format == :system
        query['value'].is_a?(Hash) ? system_created_at(query) : query['value']
      else
        return query['value'] unless query['value'].include?('-')
        from, to = query['value'].split('-')
        {
          'from' => format_time(from),
          'to' => format_time(to)
        }
      end
    end

    def system_created_at(query)
      [format_time(query['value']['from']), format_time(query['value']['to'])].join(' - ')
    end

    def format_time(time)
      time = Time.zone.parse(time)
      format.eql?(:system) ? time.strftime('%d %b %Y') : time.iso8601
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
      [ SPAM_CONDITION, DELETED_CONDITION ]
    end

    def deleted_custom_field_or_spam?(query)
      return true if REMOVE_FFNAME_FOR.include?(query['condition'])
      if format == :system && query['type'] == 'custom_field'
        ff_alias_name_map["#{query['condition']}_#{Account.current.id}"].nil?
      elsif format == :presentable && is_flexi_field?(query)
        ff_alias_name_map[get_ff_field_name_from_query(query)].nil?
      else
        false
      end
    end

    def all_ff_fields
      @all_ff_fields ||= Account.current.flexifield_def_entries.find(:all, select: [:flexifield_alias, :flexifield_name]).map(&:attributes)
    end

    def ff_alias_name_map
      @alias_name_map ||= Hash[all_ff_fields.map {|fields| [fields['flexifield_alias'], fields['flexifield_name']]}]
    end

    def ff_name_alias_map
      @name_alias_map ||= Hash[all_ff_fields.map {|fields| [fields['flexifield_name'], fields['flexifield_alias']]}]
    end

end