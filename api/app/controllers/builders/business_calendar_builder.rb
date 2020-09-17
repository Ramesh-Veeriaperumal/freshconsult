module BusinessCalendarBuilder
  include ApiBusinessCalendarConstants

  def construct_business_hours_time_data
    return if action == :update && params[cname]['channel_business_hours'].nil?

    current_time_data = find_freshdesk_business_hours
    @item.business_time_data = {}.with_indifferent_access
    @item.business_time_data[:fullweek] = find_freshdesk_business_type == ALL_TIME_AVAILABLE
    @item.business_time_data[:weekdays] = current_time_data ? construct_weekdays(current_time_data) : (0..6).to_a
    @item.business_time_data[:working_hours] = find_freshdesk_business_type == ALL_TIME_AVAILABLE ? construct_24x7_working_hours : construct_working_hours(current_time_data)
  end

  def construct_holiday_data
    current_holiday_data = params[cname][:holidays]
    return if current_holiday_data.nil?

    @item.holiday_data = format_holiday_data(current_holiday_data)
  end

  def construct_default_params
    # This is required like in below implementation we are having "params[cname][name] || prev_value"
    # So if params[cname][name] = nil It will always take prev_value for description
    # So for this I have added like nil|| "" will take  as empty string and ""||prev_value will take empty string for description
    params[cname][:description] = params[cname][:description] || '' if params[cname].key? :description
    CREATE_PARAMS.each_pair do |name, attr_name|
      prev_value = @item.safe_send(attr_name)
      @item.safe_send("#{attr_name}=", params[cname][name] || prev_value)
    end
  end

  private

    def find_freshdesk_business_hours
      (params[cname][:channel_business_hours] || []).each do |channel_hours|
        return channel_hours[:business_hours] if channel_hours.try(:[], :channel) == TICKET_CHANNEL
      end
    end

    def find_freshdesk_business_type
      (params[cname][:channel_business_hours] || []).each do |channel_hours|
        return channel_hours[:business_hours_type] if channel_hours.try(:[], :channel) == TICKET_CHANNEL
      end
    end

    def format_holiday_data(current_holiday_data)
      current_holiday_data.map do |holiday|
        [holiday[:date], holiday[:name]]
      end
    end

    def construct_weekdays(business_hours_data)
      business_hours_data.each_with_object([]) do |data, mapping|
        mapping << WEEKDAY_HUMAN_LIST.index(data[:day])
      end.uniq
    end

    def construct_working_hours(business_hours_data)
      business_hours_data.each_with_object({}) do |data, mapping|
        day_num = WEEKDAY_HUMAN_LIST.index(data[:day])
        hour_data = {}.with_indifferent_access
        hour_data[WORKING_HOURS_INFO[0]] = convert_to_business_time(data[:time_slots][0][:start_time])
        hour_data[WORKING_HOURS_INFO[1]] = convert_to_business_time(data[:time_slots][0][:end_time])
        mapping[day_num] = hour_data
      end
    end

    def construct_24x7_working_hours
      hours_data = {}
      WEEKDAY_HUMAN_LIST.each_with_index do |_, index|
        hours_data[index] = { WORKING_HOURS_INFO[0] => '00:00:00 am', WORKING_HOURS_INFO[1] => '11:59:59 pm' }.with_indifferent_access
      end
      hours_data
    end

    def convert_to_business_time(time)
      hh, mm = time.split(':').map(&:to_i)
      if hh < 12
        "#{round_of_clock(hh)}:#{round_of_clock(mm)}:00 am"
      else
        mm == 59 ? "#{round_of_clock(hh % 12)}:#{round_of_clock(mm)}:59 pm" : "#{round_of_clock(hh % 12)}:#{round_of_clock(mm)}:00 pm"
      end
    end

    def round_of_clock(num)
      format('%.2d', num)
    end
end
