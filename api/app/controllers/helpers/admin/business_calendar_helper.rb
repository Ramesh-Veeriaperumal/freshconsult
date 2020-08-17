module Admin::BusinessCalendarHelper
  include ApiBusinessCalendarConstants
  include Admin::TicketFieldsErrorHelper
  include UtilityHelper

  def validate_holidays_data
    holidays.each do |holiday_data|
      holiday_data = deep_symbolize_keys(holiday_data)
      if (HOLIDAYS_PERMITTED_PARAMS & holiday_data.keys.map(&:to_s)) != HOLIDAYS_PERMITTED_PARAMS ||
         HOLIDAYS_PERMITTED_PARAMS.size != holiday_data.size
        not_included_error(:holidays, HOLIDAYS_PERMITTED_PARAMS.join(', '))
        break if errors.present?
      end
      month, day = holiday_data[:date].split(' ')
      not_included_error(:'holidays[:date]', VALID_MONTH_NAMES.join(', ')) if !month.respond_to?(:to_sym) || VALID_MONTH_NAMES.exclude?(month.to_sym)
      break if errors.present?

      source_icon_id_error(:'holidays[:date]', VALID_MONTH_NAME_DAY_LIST[month.to_sym], 1, :invalid_date_for_holidays) if !day.to_s.match(/^[0-9]{0,2}$/) || day.to_i < 1 || day.to_i > VALID_MONTH_NAME_DAY_LIST[month.to_sym]
    end
    duplicate_holiday_date?(holidays.map { |hol| hol[:date] }) if errors.blank?
  end

  def validate_channel_business_hours
    channel_business_hours.each do |channel_data|
      channel_data.permit(*CHANNEL_BUSINESS_HOURS_PARAMS)
      channel_data = deep_symbolize_keys(channel_data)
      valid_business_type?(channel_data[:business_hours_type]) if errors.blank?
      valid_channel?(channel_data[:channel]) if errors.blank?
      valid_24x7_business_hours?(channel_data) if errors.blank? && channel_data.key?(:business_hours)
      valid_custom_business_hours?(channel_data[:business_hours]) if errors.blank? && channel_data[:business_hours_type] != ALL_TIME_AVAILABLE
      valid_time_slots_count?(channel_data[:business_hours], channel_data[:channel]) if errors.blank? && channel_data[:business_hours_type] != ALL_TIME_AVAILABLE
    end
  end

  private

    def duplicate_holiday_date?(dates)
      duplicate_label_error(:holidays, :date, :duplicate_holiday_date) if dates.size != dates.uniq.size
    end

    def duplicate_business_day?(days)
      duplicate_label_error(:"channel_business_hours['business_hours']", :day, :duplicate_business_day) if days.size != days.uniq.size
    end

    def valid_time_slots_count?(business_hours, channel)
      (business_hours || []).each do |hour_data|
        next unless hour_data[:time_slots].size > TIME_SLOT_COUNT_PER_CHANNEL[channel]

        unexpected_value_for_attribute(:'channel_business_hours[:business_hours][:time_slots]', channel, :time_slot_count_for_channel_error)
      end
    end

    def valid_time_period?(key_name, start_hh, start_mm, end_hh, end_mm)
      if (start_mm == 59 && start_hh != 23) || (end_hh != 23 && end_mm == 59)
        errors[key_name] << :invalid_minute_on_24_hours
        return
      end
      errors[key_name] << :invalid_time_slot if start_hh > end_hh || (start_hh == end_hh && start_mm == end_mm)
    end

    def valid_time_data?(start_time, end_time)
      key_name = :'channel_business_hours[:business_hours][:time_slots][:start_time/end_time]'
      if [start_time, end_time].any? { |time| time.to_s.match(/^[0-9]{2}[:][0-9]{2}$/).nil? }
        invalid_data_type(key_name, :"HH:MM", :INVALID)
        return
      end
      start_hh, start_mm = start_time.to_s.split(':')
      end_hh, end_mm = end_time.to_s.split(':')
      start_hh, end_hh, start_mm, end_mm = [start_hh, end_hh, start_mm, end_mm].map(&:to_i)
      errors[key_name] << :invalid_start_end_business_time if ([start_hh, end_hh].any? { |hh| hh < 0 || hh > 23 }) || ([start_mm, end_mm].any? { |mm| VALID_MINUTES_DATA.exclude?(mm) })
      valid_time_period?(key_name, start_hh, start_mm, end_hh, end_mm)
    end

    def valid_time_slots?(slots)
      invalid_data_type(:'channel_business_hours[:business_hours][:time_slots]', Array, :INVALID) unless slots.is_a?(Array)
      blank_value_for_attribute(:'channel_business_hours[:business_hours]', :time_slots) if slots.blank?
      return if errors.present?

      slots.each do |time_slot|
        if (TIME_SLOTS_PARAMS & time_slot.keys.map(&:to_s)) != TIME_SLOTS_PARAMS ||
           TIME_SLOTS_PARAMS.size != time_slot.size
          not_included_error(:'channel_business_hours[:business_hours][:time_slots]', TIME_SLOTS_PARAMS.join(', '))
          break if errors.present?
        end
        valid_time_data?(time_slot[:start_time], time_slot[:end_time]) if errors.blank?
      end
    end

    def valid_business_day?(day)
      not_included_error(:'channel_business_hours[:business_hours][:day]', WEEKDAY_HUMAN_LIST.join(', ')) if WEEKDAY_HUMAN_LIST.exclude?(day.to_s)
    end

    def valid_custom_business_hours?(business_hours)
      blank_value_for_attribute(:channel_business_hours, :business_hours) if business_hours.blank?
      invalid_data_type(:'channel_business_hours[:business_hours]', Array, :INVALID) unless business_hours.is_a?(Array)
      return if errors.present?

      business_hours.each do |each_business_hour|
        if (CUSTOM_BUSINESS_HOURS_PARAMS & each_business_hour.keys.map(&:to_s)) != CUSTOM_BUSINESS_HOURS_PARAMS ||
           CUSTOM_BUSINESS_HOURS_PARAMS.size != each_business_hour.size
          not_included_error(:'channel_business_hour[:business_hours]', CUSTOM_BUSINESS_HOURS_PARAMS.join(', '))
          break if errors.present?
        end
        valid_time_slots?(each_business_hour[:time_slots]) if errors.blank?
        valid_business_day?(each_business_hour[:day]) if errors.blank?
      end
      duplicate_business_day?(business_hours.map { |bh| bh[:day].downcase }) if errors.blank?
    end

    def valid_business_type?(type)
      not_included_error(:'channel_business_hours[:business_hours_type]', BUSINESS_HOURS_TYPE_ALLOWED.join(', ')) if BUSINESS_HOURS_TYPE_ALLOWED.exclude?(type.to_s)
    end

    def valid_channel?(name)
      not_included_error(:'channel_business_hours[:channel]', VALID_CHANNEL_PARAMS.join(', ')) if VALID_CHANNEL_PARAMS.exclude?(name.to_s)
    end

    def valid_24x7_business_hours?(channel_data)
      unexpected_value_for_attribute(:"channel_business_hours[#{ALL_TIME_AVAILABLE}]", :business_hours) if channel_data[:business_hours_type] == ALL_TIME_AVAILABLE && channel_data.key?(:business_hours)
    end
end
