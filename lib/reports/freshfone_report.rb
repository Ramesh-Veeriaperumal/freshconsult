# Copyright © 2014 Freshdesk Inc. All Rights Reserved.
module Reports::FreshfoneReport

  include Reports::ActivityReport

  UNASSIGNED_GROUP = "-1"
  ALL_NUMBERS = "0"
  ALL_CALLS = "0"
  MAX_ALLOWED_MONTHS = 6

  def build_criteria
    @report_date = params[:date_range]
    @start_date = start_date
    @end_date = end_date
    @time_diff = (DateTime.parse(@end_date) - DateTime.parse(@start_date)).to_i
    set_default_date_range if @time_diff > MAX_ALLOWED_MONTHS * 31 #usually its 184 (we keep it 186 for convenience)
    @call_type = params[:call_type] || Freshfone::Call::CALL_TYPE_HASH[:incoming]
    @group_id = params[:group_id]
    @freshfone_number = params[:freshfone_number] || Account.current.freshfone_numbers.first.id
    @business_hours = params[:business_hours]
  end

  def filter(start_date, end_date)
    scoper(start_date,end_date).select("#{report_query}").where(select_conditions).group('freshfone_calls.user_id').order('count desc')
  end

  def call_duration_in_mins(duration)
    if duration >= 3600
      "%02d:%02d:%02d" % [duration / 3600, (duration / 60) % 60, duration % 60]
    else
      "%02d:%02d" % [(duration / 60) % 60, duration % 60]
    end
  end

  def previous_time_range
    @prev_start_time = previous_start
    @prev_end_time = previous_end
  end

  def prepare_filters
    @cached_filter['date_range'] = get_date_range(@cached_filter['date_range_type'], @cached_filter['date_range'])
    params.merge!(@cached_filter)
  end

  private 

    def scoper(start_date, end_date)
      Account.current.freshfone_calls.created_at_inside(start_date, end_date)
    end

    def select_columns
      query_columns = ['account_id', 'id', 'created_at', 'freshfone_number_id','call_status', 'call_type', 'user_id']
      query_columns.map { |column_name| 
        "#{Freshfone::Call.table_name}.#{column_name}" 
      }.join(',')
    end

    def select_conditions
      group_condition
      conditions = ["freshfone_calls.call_type = ? #{number_condition} #{group_condition} #{business_hours_condition}", 
       @call_type]
      conditions.push(@freshfone_number) if @freshfone_number != ALL_NUMBERS
      conditions.push(@group_id) unless all_or_unassigned?
      conditions.push(@business_hours) unless @business_hours.blank?
      conditions
    end

    def number_condition
      "and freshfone_calls.freshfone_number_id = ?" if @freshfone_number != ALL_NUMBERS
    end

    def group_condition
      query = "and freshfone_calls.group_id = ? " unless group_unavailable?
      query = "and freshfone_calls.group_id IS NULL"  if @group_id == UNASSIGNED_GROUP
      query
    end

    def business_hours_condition
      "and freshfone_calls.business_hour_call = ? " unless @business_hours.blank?
    end

    def all_or_unassigned?
      group_unavailable? || @group_id == UNASSIGNED_GROUP
    end

    def group_unavailable?
      return true if @group_id.blank?
      group = Account.current.groups.find_by_id(@group_id)
      group.nil?
    end
    
    def set_default_date_range
      params[:date_range] ="#{30.days.ago.strftime("%d %B %Y")} - #{1.days.ago.strftime("%d %B %Y")}"
      Rails.logger.debug "FreshfoneSummaryReports Debug::: Resetting to default date range: #{params[:date_range]} :: for account :: #{Account.current.id} " 
      build_criteria
    end

    #over-riding it here from activity_report.rb for freshfone reports alone. Fix for default end date :8405
    #When Default dates is fixed in all other reports remove this override.
    def end_date(zone = true)
      t = zone ? Time.zone : Time
      parse_to_date.nil? ? (t.now - 1.day).end_of_day.to_s(:db) : 
      t.parse(parse_to_date).end_of_day.to_s(:db)
    end

    def report_query
      %( #{select_columns}, count(freshfone_calls.id) as count,
          sum(if(freshfone_calls.ancestry is NULL, 1,0)) as total_count,
          sum(if(freshfone_calls.ancestry is NULL and freshfone_calls.direct_dial_number is NOT NULL, 1,0)) as direct_dial_count,
          sum(if((freshfone_calls.ancestry is NOT NULL and freshfone_calls.direct_dial_number is NULL and 
            freshfone_calls.call_status not in (#{Freshfone::Call::CALL_STATUS_HASH[:completed]}, #{Freshfone::Call::CALL_STATUS_HASH[:'on-hold']},
            #{Freshfone::Call::CALL_STATUS_HASH[:'in-progress']})), 1,0)) as unanswered_transfers,
          ifnull(sum(if(freshfone_calls.call_status in (1,10),freshfone_calls.call_duration,0)),0) as total_duration,
          ifnull(sum(if(freshfone_calls.call_status = #{Freshfone::Call::CALL_STATUS_HASH[:voicemail]}, 1, 0)), 0) as voicemail,
          ifnull(sum(if(freshfone_calls.call_status not in (#{Freshfone::Call::CALL_STATUS_HASH[:completed]}, #{Freshfone::Call::CALL_STATUS_HASH[:'in-progress']},
            #{Freshfone::Call::CALL_STATUS_HASH[:'on-hold']}) and freshfone_calls.call_type = #{Freshfone::Call::CALL_TYPE_HASH[:incoming]} 
            and freshfone_calls.ancestry is NULL and freshfone_calls.direct_dial_number is NULL, 1, 0)), 0) as unanswered_call,
          ifnull(sum(if(freshfone_calls.call_status in (2,3,4,5) and freshfone_calls.ancestry is NULL and 
            freshfone_calls.call_type = #{Freshfone::Call::CALL_TYPE_HASH[:outgoing]}, 1, 0)), 0) as outbound_failed_call,
          sum(if((freshfone_calls.ancestry is NOT NULL and freshfone_calls.direct_dial_number is NOT NULL),1,0)) as external_transfers
      )
    end

    def set_filter
      @calls = filter(@start_date,@end_date)
      previous_time_range #setting the date range to previous time period 
      @old_calls = filter(@prev_start_time,@prev_end_time)
    end
  
    def get_date_range(type,custom_date_range)
      TimeZone.set_time_zone
      options = {:format => :short_day_separated, :include_year => true}
      case type
        when "Today"
          view_context.formated_date(Time.zone.now.to_date,options)
        when "Yesterday"
          view_context.formated_date(Date.yesterday,options)
        when "Last7days"
          view_context.date_range_val(6.days.ago, Time.zone.now.to_date)
        when "Last30days"
          view_context.date_range_val(29.days.ago, Time.zone.now.to_date)
        when "Last90days"
          view_context.date_range_val(89.days.ago, Time.zone.now.to_date)
        else
          custom_date_range 
        end
    end
end