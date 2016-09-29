module Freshfone::CallHistory

	def update_call
		return if current_call.blank?
		current_call.update_call_details(params.merge({ :called_agent => called_agent })).save
	end

	def update_call_status
		current_call.update_status(params).save unless current_call.blank?
	end

	def update_call_details
    current_call.update_call params
  end

  def update_conference_sid
    current_call.update_attributes(:conference_sid => params[:ConferenceSid])
  end

  def child_call
  	@child_call ||= current_call.children.last
  end
	
	def current_call
		@current_call ||= ( current_call_by_call_param || current_call_by_id || current_call_by_filter || current_call_by_parent_call_sid )
	end

	def set_current_call(call)
		@current_call = call if call.present?
	end

	def prepare_filters(data_filter)
		filters = ActiveSupport::JSON.decode data_filter['data_hash']
      filters.each do |filter| 
        case filter['condition']
          when 'created_at'
            filter['value'] = get_date_range(data_filter['date_range_type'] , filter['value'])
        end
  		end 
  	params[:data_hash] = ActiveSupport::JSON.encode filters  
  	@cached_filters['data_hash'] = params[:data_hash]   
  	params[:number_id] = @cached_filters['number_id'] if @cached_filters['number_id'].present?
	end

	def get_date_range(type, custom_value)
		TimeZone.set_time_zone
		options = {:format => :short_day_separated, :include_year => true, :translate => false}
		case type
			when "Today"
				view_context.formated_date(Time.zone.now.to_date, options)
			when "Yesterday"
				view_context.formated_date(1.day.ago, options)
			when "Last7Days"
				view_context.date_range_val(7.days.ago, Time.zone.now.to_date)
			when "Last30Days"
				view_context.date_range_val(29.days.ago, Time.zone.now.to_date)
			else
				custom_value
			end
	end

	
	private
		# Find current_call
		def called_agent
			# && params[:DialCallSid]
			agent_scoper.find_by_id(params[:agent]) if current_call.can_log_agent? && params[:agent].present? 
		end

		def freshfone_calls_scoper
			current_account.freshfone_calls
		end

		def current_call_by_call_param #Should be removed ######################################
			freshfone_calls_scoper.find_by_id(params[:call]) if params[:call].present?
		end
	
		def current_call_by_id
			freshfone_calls_scoper.find_by_id(params[:id]) if params[:id].present?
		end
	
		def current_call_by_filter
			freshfone_calls_scoper.filter_call(params[:CallSid]) if params[:CallSid].present?
		end

		def current_call_by_parent_call_sid
			freshfone_calls_scoper.filter_call(params[:ParentCallSid]) if params[:ParentCallSid].present?
		end

		def agent_scoper
			current_account.users.technicians.visible
		end

end