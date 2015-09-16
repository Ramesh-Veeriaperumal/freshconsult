module HelpdeskV2ReportsHelper

	REPORT_MAPPING = [
			["/reports/v2/glance", 					         "glance", 				"helpdesk" ],
			["/reports/v2/ticket_volume", 			     "ticket_volume", 	         "ticket-volume" ],
			["/reports/v2/performance_distribution", "performance_distribution", "performance-distribution" ],
			["/reports/v2/group_summary", 			     "group_summary",            "group-summary" ],
			["/reports/v2/agent_summary", 			     "agent_summary", 	         "agent-summary" ]
		]

	METRIC_HASH = Hash[*REPORT_MAPPING.map{ |i| [i[1], i[2]]}.flatten]

	def graph_icon(metrics_name)
		font_icon(METRIC_HASH[metrics_name], :size => 32)
	end

	def reports_sub_menu
		sub_menu = REPORT_MAPPING.map do |s|
			content_tag :li, :data => { :report => "#{s[1]}" }, :class => active_report(s[1])  do
				temp_title = "helpdesk_reports.#{s[1]}.title"
				link_content = <<HTML
          <span><i class="ficon-#{s[2]} fsize-20" size="20"></i></span>
          #{t("#{temp_title.to_s}")}
HTML
				pjax_link_to(link_content.html_safe, s[0].html_safe)
			end
		end

		sub_menu.to_s.html_safe
	end

	def active_report report
		if @report_type == report
			return "active"
		end
	end

end