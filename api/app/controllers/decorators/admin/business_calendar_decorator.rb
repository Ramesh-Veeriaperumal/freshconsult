class Admin::BusinessCalendarDecorator < ApiDecorator
  delegate :id, :name, :description, :time_zone, :is_default, to: :record

  def initialize(record, options)
    super(record)
    @groups = options[:groups]
  end

  def to_hash(list = false)
    response_hash = {
      id: id,
      name: name,
      description: description,
      time_zone: time_zone,
      default: is_default
    }
    if list
      response_hash[:group_ids] = @groups.select { |group| group.business_calendar_id == id }.map(&:id)
    else
      response_hash[:holidays] = record.holiday_data.map { |data| { name: data[1], date: data[0] } }
      response_hash[:channel_business_hours] = record.channel_bussiness_hour_data
    end
    response_hash
  end
end
