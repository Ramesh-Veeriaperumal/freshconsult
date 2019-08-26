class VA::Search::Events::SearchTransformer
  include VA::Search::VaRuleSearchTransformer
  attr_accessor :events, :type

  def initialize(events = [])
    @type = :event
    @events = events
  end

  def to_search_format
    @events.each_with_object([]) do |event, events_array|
      tranformed_data = construct_search_hash(event.rule)
      tranformed_data.each do |data|
        events_array.push(data.values.join(':'))
      end
    end
  end

  def transform_nested_field(ticket_field, data)
    transformed_nested_field = []
    from = data[:from]
    to = data[:to]
    from_picklist = ticket_field.picklist_values.find_by_value(from)
    to_picklist = ticket_field.picklist_values.find_by_value(to)
    default_hash = construct_default_hash(data, name: ticket_field.name)
    transformed_nested_field.push(default_hash.merge(
                                    from: from_picklist.try(:picklist_id) || DEFAULT_ANY_NONE[from] || from,
                                    to: to_picklist.try(:picklist_id) || DEFAULT_ANY_NONE[to] || to
                                 ))

    data[:nested_rule].each do |nested_rule|
      from_picklist = from_picklist.nil? || ANY_NONE_VALUES.include?(from) ? nil :
                        find_sub_picklist_by_value(from_picklist, nested_rule[:from]).try(:first)
      to_picklist = to_picklist.nil? || ANY_NONE_VALUES.include?(to) ? nil :
                      find_sub_picklist_by_value(to_picklist, nested_rule[:to]).try(:first)
      from = nested_rule[:from]
      to = nested_rule[:to]
      name = fetch_custom_field(nested_rule[:name]).try(:name)

      transformed_nested_field.push(
        name: display_name(name),
        from: from_picklist.try(:picklist_id) || DEFAULT_ANY_NONE[from] || from,
        to: to_picklist.try(:picklist_id) || DEFAULT_ANY_NONE[to] || to
      )
    end
    transformed_nested_field
  end

  def transform_custom_dropdown(custom_field, data, default_hash)
    if data.key?(:value)
      custom_dropdown_values(custom_field, data[:value]).map do |id|
        default_hash.merge(value: id)
      end
    elsif data.key?(:from)
      [default_hash.merge(
        from: custom_dropdown_values(custom_field, data[:from]).first,
        to: custom_dropdown_values(custom_field, data[:to]).first
      )]
    end
  end

  def transform_fields(name, data, default_hash)
    if data.key?(:value)
      handle_value(data[:value]).map do |val|
        default_hash.merge(value: construct_search_value(name, val))
      end
    elsif data.key?(:from)
      [default_hash.merge(
        from: construct_search_value(name, data[:from]),
        to: construct_search_value(name, data[:to])
      )]
    end
  end

  def fetch_custom_field(name)
    custom_ticket_fields.find { |t| t.column_name == name.to_s }
  end
end