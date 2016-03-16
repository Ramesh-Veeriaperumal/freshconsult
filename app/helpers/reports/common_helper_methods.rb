module Reports::CommonHelperMethods

	DEFAULT_REPORTS     = ["agent_summary", "group_summary"]
	ADVANCED_REPORTS    = DEFAULT_REPORTS + ["glance"]
  	ENTERPRISE_REPORTS  = ADVANCED_REPORTS + ["ticket_volume", "performance_distribution","customer_report"] 

  	SAVE_REPORTS_LIMIT = {
	    SubscriptionPlan::SUBSCRIPTION_PLANS[:blossom_classic] => 25,
	    SubscriptionPlan::SUBSCRIPTION_PLANS[:blossom] => 25,
	    SubscriptionPlan::SUBSCRIPTION_PLANS[:garden_classic] => 25,
	    SubscriptionPlan::SUBSCRIPTION_PLANS[:garden] => 25,
	    SubscriptionPlan::SUBSCRIPTION_PLANS[:estate_classic] => 50,
	    SubscriptionPlan::SUBSCRIPTION_PLANS[:estate] => 50,
	    SubscriptionPlan::SUBSCRIPTION_PLANS[:forest] => 50
	}

	REPORT_TYPE_BY_KEY = {
	    "glance"                       => 1001,
	    "ticket_volume"                => 1002,
	    "performance_distribution"     => 1003,
	    "agent_summary"                => 1004,
	    "group_summary"                => 1005,
	    "customer_report"              => 1006,
	    "chat_summary"                 => 1007,
	    "phone_summary"                => 1008,
	    "timesheet_reports"            => 1009,
	    "satisfaction_survey"          => 1010,
	}
  	
	REPORT_TYPE_BY_NAME = REPORT_TYPE_BY_KEY.keys.freeze
 
	REPORT_MAPPING = [
			["/reports/v2/glance", 					 "glance", 				     "helpdesk_at_glance" ,               "analysis"],
			["/reports/v2/ticket_volume", 			 "ticket_volume", 	         "ticket-volume" , 	     			  "analysis"],
			["/reports/phone/summary_reports",       "phone_summary",            "phone_summary" ,                	  "analysis"],
			["/reports/freshchat/summary_reports",   "chat_summary",             "live_chat" ,                        "analysis"],
			["/reports/v2/agent_summary", 			 "agent_summary", 	         "agent-summary" ,	    	   	  "productivity"],
			["/reports/v2/group_summary", 			 "group_summary",            "group-summary" ,	  			  "productivity"],
			["/reports/v2/performance_distribution", "performance_distribution", "performance-distribution" ,     "productivity"],      
			["/timesheet_reports",                   "timesheet_reports",        "time_sheet" ,      			  "productivity"],
			["/reports/v2/customer_report",          "customer_report",          "customer_reports" ,  		"customer_happiness"],
			["/survey/reports",                      "satisfaction_survey",    	 "customer_satisfaction",   "customer_happiness"]
		]

	PJAX_SUPPORT_REPORTS = ["glance","ticket_volume","agent_summary","group_summary","customer_report","performance_distribution"]

	METRIC_HASH = Hash[*REPORT_MAPPING.map{ |i| [i[1], i[2]]}.flatten]
	REPORT_CATEGORY = Hash[*REPORT_MAPPING.map{ |i| [i[1], i[3]]}.flatten] 
	
	def graph_icon(metrics_name)
		font_icon(METRIC_HASH[metrics_name], :size => 32)
	end

	def reports_sub_menu
		#Find category
		current_report_category = REPORT_CATEGORY[@report_type]
		
		sub_menu = REPORT_MAPPING.map do |s|
			next unless "#{s[3]}" == current_report_category && has_scope?("#{s[1]}")
			content_tag :li, :data => { :report => "#{s[1]}" }, :class => active_report(s[1])  do
				temp_title = "helpdesk_reports.#{s[1]}.title"
				link_content = <<HTML
          <span><i class="ficon-#{s[2]} fsize-20" size="20"></i></span>
          #{t("#{temp_title.to_s}")}
HTML
			PJAX_SUPPORT_REPORTS.include?(@report_type) && PJAX_SUPPORT_REPORTS.include?("#{s[1]}") ? pjax_link_to(link_content.html_safe, s[0].html_safe)
																									: link_to(link_content.html_safe, s[0].html_safe)

			end
		end.compact

		sub_menu.to_s.html_safe
	end

	def active_report report
		return "active" if @report_type == report
	end

	def has_scope?(report_type)
	    if report_type == "phone_summary"
	   	  current_account.features_included?(:freshfone) && !current_account.freshfone_numbers.empty?
	   	elsif report_type == "chat_summary"
	   	  !current_account.subscription.suspended? && current_account.features_included?(:chat) && current_account.chat_setting.display_id
	   	elsif report_type == "timesheet_reports"
	   	  current_account.features_included?(:timesheets) && privilege?(:view_time_entries)
	   	elsif report_type == "satisfaction_survey"
	   	  current_account.survey_enabled?
	    elsif current_account.features_included?(:enterprise_reporting)
	      ENTERPRISE_REPORTS.include?(report_type)
	    elsif current_account.features_included?(:advanced_reporting)
	      ADVANCED_REPORTS.include?(report_type)
	    else
	      DEFAULT_REPORTS.include?(report_type)
	    end 
  	end

    def report_filter_data_hash
      report_type_id  = REPORT_TYPE_BY_KEY[report_type]
      r_f = current_user.report_filters.by_report_type(report_type_id).order_by_latest
      r_f.inject({}) do |r, h|
        r[h[:id]] = {:name => h[:filter_name], :data => h[:data_hash]}
        r
      end
      @report_filter_data = r_f
    end

    def construct_filters
      @data_map = {}
      unless params[:data_hash].blank?
	      params[:data_hash].each do |key, value| 
	      	@data_map[escape_keys(key)] = {}
	      	@data_map[escape_keys(key)] = escape_keys(value) 
	      end 
	  end
      @report_type_id, @filter_name = REPORT_TYPE_BY_KEY[report_type], CGI.escapeHTML(params[:filter_name])
    end  

    def escape_keys(value)
    	case 
	    when value.is_a?(Array)
			value.map { |obj| escape_keys(obj) }
	   	when value.is_a?(Hash)
	   		new_hash = {}
	   		value.each do |k,v| 
	   		   new_hash[escape_keys(k)] = {}	
	   		   new_hash[escape_keys(k)] = escape_keys(v) 
	   		end
	   		new_hash
	   	when value.is_a?(String)
	   		CGI::escapeHTML(value)
	    else
	        value
	 	end
  	end

    def max_limit?
      max_limit = SAVE_REPORTS_LIMIT[Account.current.subscription.subscription_plan.name] || 25
      if current_user.report_filters.count > max_limit
        render json: "#{max_limit}", status: :unprocessable_entity
      end
    end

end