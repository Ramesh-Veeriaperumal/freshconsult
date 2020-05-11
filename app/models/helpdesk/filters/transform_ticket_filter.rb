class Helpdesk::Filters::TransformTicketFilter
  include FilterFactory::Tickets::FieldTransformMethods
  include Helpdesk::Filters::TicketFilterTransformationConstants

  def initialize
    @transformed_data_hash = { operator: 'AND', conditions: [] }
    @account = Account.current
  end

  def process_args(data)
    data[:data_hash].uniq.each do |filter|
      temp_hash = {}
      temp_hash[:field] = transform_field_name(filter)
      if filter['condition'] == 'created_at' || fsm_appointment_filter?(filter)
        @data_type = 'date_time'
        temp_hash.merge! transform_date_filters(filter)
      else
        temp_hash[transform_operator(filter)] = transform_value(filter)
      end
      temp_hash[:type] = transform_type
      temp_hash[:default_field] = check_and_set_default_field(filter)
      @transformed_data_hash[:conditions] << temp_hash
    end
    @transformed_data_hash
  end

  def transform_operator(data)
    (OPERATOR_MAPPING.stringify_keys[data['condition']].presence || data['operator']).to_sym
  end

  def transform_value(data)
    condition = data['condition']
    if condition == 'helpdesk_tags.name'
      @account.tags.where(name: data['value'].split(',')).pluck(:id)
    elsif check_data_type(:number, condition)
      @data_type = 'number'
      data['value'].split(',').map(&:to_i)
    elsif check_data_type(:string, condition)
      @data_type = 'string'
      data['value'].split(',')
    elsif check_data_type(:boolean, condition)
      @data_type = 'boolean'
      data['value']
    elsif check_data_type(:date_time, condition)
      @data_type = 'date_time'
      values = data['value'].split(',')
      temp_array = []
      values.each do |value|
        temp_array << parse_date(DUE_BY_MAPPING[value.to_s])
      end
      temp_array
    else
      @data_type = 'string'
      data['value'].split(',')
    end
  end

  def transform_field_name(data)
    data['ff_name'] == 'default' || data['ff_name'].nil? ? FILTER_NAME_MAPPING[data['condition']].presence || data['condition'] : data['ff_name']
  end

  def transform_type
    @data_type
  end

  def check_and_set_default_field(data)
    data['ff_name'].nil? || data['ff_name'] == 'default' ? true : false
  end

  def transform_date_filters(data)
    Time.zone = @account.time_zone
    value = data['value']
    if value.to_s.is_number?
      { gte: ('now-' + (min_to_hr(value.first.to_i))) }
    elsif value.is_a?(Hash)
      fetch_date_range(Time.zone.parse(value[:from]).utc.iso8601, Time.zone.parse(value[:to]).end_of_day.utc.iso8601)
    elsif value.include? '-'
      from, to = value.split(' - ')
      fetch_date_range(Time.zone.parse(from).utc.iso8601, Time.zone.parse(to).end_of_day.utc.iso8601)
    else
      parse_date(value)
    end
  end

  def parse_date(value)
    case value
    when 'today'
      fetch_date_range('now/d', 'now+1d/d')
    when 'yesterday'
      fetch_date_range('now-1d/d', 'now/d')
    when 'tomorrow'
      fetch_date_range('now+1d/d', 'now+2d/d')
    when 'week'
      fetch_date_range('now/w', 'now+1w/w')
    when 'last_week'
      fetch_date_range('now-1w/w', 'now/w')
    when 'next_week'
      fetch_date_range('now+1w/w', 'now+2w/w')
    when 'month'
      fetch_date_range('now/M', 'now+1M/M')
    when 'last_month'
      fetch_date_range('now-1M/M', 'now/M')
    when 'two_months'
      fetch_date_range('now-2M/M', 'now/M')
    when 'six_months'
      fetch_date_range('now-6M/M', 'now/M')
    when 'due_in_eight'
      fetch_date_range('now', 'now+8h')
    when 'due_in_four'
      fetch_date_range('now', 'now+4h')
    when 'due_in_two'
      fetch_date_range('now', 'now+2h')
    when 'due_in_one'
      fetch_date_range('now', 'now+1h')
    when 'due_in_half_hour'
      fetch_date_range('now', 'now+30m')
    when 'overdue', 'in_the_past'
      { lt: 'now' }
    else
      { eq: 'none' }
    end
  end

  def fetch_date_range(from = nil, to = nil)
    { gte: from, lt: to }
  end

  def min_to_hr(value)
    (value % 60).zero? ? (value / 60).to_s + 'h' : value.to_s + 'm'
  end

  def check_data_type(data_type, condition)
    DATA_TYPE_MAPPING[data_type].include?(condition)
  end
end
