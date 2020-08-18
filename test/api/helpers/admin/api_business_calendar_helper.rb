module Admin::ApiBusinessCalendarHelper
  DAYS = %w[sunday monday tuesday wednesday thursday friday saturday].freeze

  def ember_business_hours_create_pattern(business_hour, options = {})
    response = {
      name: business_hour.try(:name),
      description: business_hour.try(:description),
      default: business_hour.try(:is_default),
      time_zone: business_hour.try(:time_zone),
      holidays: options[:holidays],
      channel_business_hours: options[:channel_business_hours]
    }
    response.merge!(id: business_hour.try(:id)) if business_hour.present?
    response
  end

  def dummy_business_calendar_default_params
    {
      name: 'Dark web with social engineering',
      description: 'useless',
      time_zone: 'Edinburgh'
    }
  end

  def dummy_holiday_data
    {
      "holidays": [
        {
          "date": 'Feb 29',
          "name": 'feb 31 holiday'
        },
        {
          "date": 'Apr 1',
          "name": 'april 30 holiday'
        }
      ]
    }
  end

  def dummy_channel_business_hours(channel = 'ticket', business_type = 'custom')
    [
      {
        'channel': channel,
        "business_hours_type": business_type.to_s
      }
    ]
  end

  def dummy_business_hours_data(day_to_use = 7, options = {})
    {
      "business_hours": randomized_list((0..6).to_a, 0, 6).slice(0, day_to_use).each_with_object([]) do |day_num, mapping|
        mapping << {
          "day": DAYS[day_num],
          "time_slots": options[:day_num] || [
            {
              "end_time": '23:59',
              "start_time": '00:00'
            }
          ]
        }
      end
    }
  end

  def randomized_list(list, from, to)
    (from..to).each do |index|
      next_ind = rand(to - index + 1) + from
      list[from], list[next_ind] = list[next_ind], list[from]
    end
    list
  end
end
