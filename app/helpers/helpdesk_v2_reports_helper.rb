module HelpdeskV2ReportsHelper

	REPORT_MAPPING = [
			["/reports/v2/glance", 					 "glance", 				     "helpdesk" ],
			["/reports/v2/ticket_volume", 			 "ticket_volume", 	         "ticket-volume" ],
			["/reports/v2/performance_distribution", "performance_distribution", "performance-distribution" ],
			["/reports/v2/group_summary", 			 "group_summary",            "group-summary" ],
			["/reports/v2/agent_summary", 			 "agent_summary", 	         "agent-summary" ],
			["/reports/v2/customer_report",          "customer_report",          "customer-report"]
		]

	METRIC_HASH = Hash[*REPORT_MAPPING.map{ |i| [i[1], i[2]]}.flatten]
	
	DEFAULT_DATE_RANGE = 29 

	DUMP_TIME_IN_SECONDS = [1800,16200,30600,45000,59400,73800,88200] 

	def graph_icon(metrics_name)
		font_icon(METRIC_HASH[metrics_name], :size => 32)
	end

	def reports_sub_menu
		sub_menu = REPORT_MAPPING.map do |s|
			next unless has_scope?("#{s[1]}")
			content_tag :li, :data => { :report => "#{s[1]}" }, :class => active_report(s[1])  do
				temp_title = "helpdesk_reports.#{s[1]}.title"
				link_content = <<HTML
          <span><i class="ficon-#{s[2]} fsize-20" size="20"></i></span>
          #{t("#{temp_title.to_s}")}
HTML
				pjax_link_to(link_content.html_safe, s[0].html_safe)
			end
		end.compact

		sub_menu.to_s.html_safe
	end

	def active_report report
		if @report_type == report
			return "active"
		end
	end

	def default_date_range lag
		return [(DEFAULT_DATE_RANGE + lag).days.ago, lag.days.ago]
	end

	def fetch_dump_time
		current_seconds_since_midnight   = Time.now.utc.seconds_since_midnight.seconds.to_i
		next_dump_seconds_since_midnight = DUMP_TIME_IN_SECONDS.select{|sec| sec if sec > current_seconds_since_midnight}.first
		next_dump_time = Time.now.utc.beginning_of_day + next_dump_seconds_since_midnight
		if current_account.features_included?(:enterprise_reporting)
			"Next data refresh will be on #{Time.parse(next_dump_time.to_s).in_time_zone(current_account.time_zone).strftime('%d %b,%l:%M %p %Z')}" 
	    end 
	end

end