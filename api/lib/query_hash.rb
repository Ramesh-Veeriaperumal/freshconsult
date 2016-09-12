class QueryHash

  attr_accessor :query_hash, :format
  REMOVE_FFNAME_FOR = %w(spam deleted).freeze

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
      query_hash.dup.map { |query| transform_query(query) }
    end

    def transform_query(query)
      result = query.slice('condition', 'operator', 'value')
      result['value'] = transform_value(result['value'])
      return result if skip_transform?(query)
      result.merge!(transform_condition(query))
      if format == :presentable
        result['type'] = is_flexi_field?(query) ? 'custom_field' : 'default'
      end
      result
    end

    def skip_transform?(query)
      ((format == :type) && query.has_key?("type")) ||
        ((format == :system) && !query.has_key?("type"))
    end

    def transform_value(val)
      if format.eql?(:system)
        val.is_a?(Array) ? val.join(',') : val
      else
        val.is_a?(String) ? val.split(',') : val
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
        condition = { 'condition' => "flexifields.#{ff_field_name(ff_name)}", 'ff_name' => ff_name }
      end
      condition
    end

    def is_flexi_field?(query)
      query['ff_name'] != 'default' && query['condition'].include?('flexifield')
    end

    def ff_field_name(name)
      Account.current.flexifield_def_entries.find_by_flexifield_alias(name).flexifield_name
    end

    def ff_field_alias(query)
      name = query['ff_name']
      unless name.present?
        ff_name = query['condition'].gsub('flexifields.', '')
        name = Account.current.flexifield_def_entries.find_by_flexifield_name(ff_name).flexifield_alias
      end
      TicketDecorator.display_name(name)
    end
end