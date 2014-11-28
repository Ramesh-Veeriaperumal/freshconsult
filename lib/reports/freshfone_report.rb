# Copyright © 2014 Freshdesk Inc. All Rights Reserved.
module Reports::FreshfoneReport

  include Reports::ActivityReport

  def build_criteria
    @report_date = params[:date_range]
    @start_date = start_date
    @end_date = end_date
    @call_type = params[:call_type] || 0
    @group_id = params[:group_id] || []
    @freshfone_number = params[:freshfone_number] || current_account.freshfone_numbers.first.id
  end

  def filter(start_date, end_date)
    scoper(start_date,end_date).find(:all,
      :select =>"#{report_query}",
      :joins => join_calls_meta,
      :conditions => select_conditions, 
      :group => "freshfone_calls.user_id",
      :order => "count desc")
  end

  def call_duration_in_mins(duration)
    format = (duration >= 3600) ? "%H:%M:%S" : "%M:%S"
    Time.at(duration).gmtime.strftime(format)
  end

  def previous_time_range
    @prev_start_time = previous_start
    @prev_end_time = previous_end
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
      conditions = {}
      conditions[:freshfone_calls_meta] = { :group_id => @group_id } unless @group_id.empty?
      conditions[:call_type] = @call_type unless(@call_type.blank? || @call_type.to_i == 0)
      conditions[:freshfone_number_id] = @freshfone_number unless @freshfone_number.blank?
      conditions
    end

    def join_calls_meta
      @group_id.empty? ? nil : "inner join freshfone_calls_meta on freshfone_calls.id = freshfone_calls_meta.call_id and freshfone_calls.account_id = freshfone_calls_meta.account_id"
    end

    def report_query
      %( #{select_columns}, count(freshfone_calls.id) as count,
          sum(if(freshfone_calls.ancestry is NULL, 1,0)) as total_count,
          sum(if((freshfone_calls.ancestry is NOT NULL and freshfone_calls.call_status not in (#{Freshfone::Call::CALL_STATUS_HASH[:completed]}, 
            #{Freshfone::Call::CALL_STATUS_HASH[:'in-progress']})), 1,0)) as unanswered_transfers,
          ifnull(sum(if(freshfone_calls.call_status in (1,8,10),freshfone_calls.call_duration,0)),0) as total_duration,
          ifnull(sum(if(freshfone_calls.call_status = #{Freshfone::Call::CALL_STATUS_HASH[:voicemail]}, 1, 0)), 0) as voicemail,
          ifnull(sum(if(freshfone_calls.call_status not in (#{Freshfone::Call::CALL_STATUS_HASH[:completed]}, #{Freshfone::Call::CALL_STATUS_HASH[:'in-progress']}) 
            and freshfone_calls.call_type = #{Freshfone::Call::CALL_TYPE_HASH[:incoming]} and freshfone_calls.ancestry is NULL, 1, 0)), 0) as unanswered_call,
          ifnull(sum(if(freshfone_calls.call_status in (2,3,4,5) and freshfone_calls.ancestry is NULL and 
            freshfone_calls.call_type = #{Freshfone::Call::CALL_TYPE_HASH[:outgoing]}, 1, 0)), 0) as outbound_failed_call
      )
    end
end