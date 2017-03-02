module Reports::GlanceReportsHelper
	UP_RED       = "report-arrow report-arrow-up report-arrow-red"
	UP_GREEN     = "report-arrow report-arrow-up report-arrow-green"
	DOWN_RED     = "report-arrow report-arrow-down report-arrow-red"
	DOWN_GREEN   = "report-arrow report-arrow-down report-arrow-green"
	METRIC_ICONS ={
		:received_tickets         => [DOWN_RED,UP_GREEN],
		:resolved_tickets         => [DOWN_RED,UP_GREEN],
		:backlog_tickets          => [DOWN_GREEN,UP_RED],
		:avgresponsetime          => [DOWN_GREEN,UP_RED],
		:avgfirstresptime         => [DOWN_GREEN,UP_RED],
		:avgresolutiontime        => [DOWN_GREEN,UP_RED],
		:avgcustomerinteractions  => [DOWN_GREEN,UP_RED],
		:avgagentinteractions     => [DOWN_GREEN,UP_RED],
		:num_of_reopens           => [DOWN_GREEN,UP_RED],
		:num_of_reassigns         => [DOWN_GREEN,UP_RED],
		:sla_tickets              => [DOWN_RED,UP_GREEN],
		:fcr_tickets              => [DOWN_RED,UP_GREEN],
		:hours_tracked            => [DOWN_RED,UP_GREEN],
		:billable_hours           => [DOWN_RED,UP_GREEN],
		:non_billable_hours       => [DOWN_GREEN,UP_RED],
		:num_of_calls             => [DOWN_GREEN,UP_RED],
		:missed_calls             => [DOWN_GREEN,UP_RED],
		:answered_calls           => [DOWN_RED,UP_GREEN]
	}

	def percentage_change(old_val, new_val, metric_label)
		#Changing "" to {} for rails 3. bug ticket: #3460
		return {} if old_val.blank? || old_val == 0
		comparison_hash = {}
		percentage_val = ((new_val - old_val).to_f/old_val.to_f) * 100
		comparison_hash[:val] = (number_to_percentage(percentage_val.abs, :precision => 2))
		if(percentage_val < 0 )
			comparison_hash[:class] = METRIC_ICONS[metric_label][0]
		else
			comparison_hash[:class] = METRIC_ICONS[metric_label][1]
		end
		comparison_hash
	end

	def in_hours (hhnmm)
		hh,mm = hhnmm.split(':')
		hh.to_f + (mm.to_f/60)
	end

	def in_hrs_mins(seconds)
		return "00:00" if seconds.blank?
		hours = seconds.to_i/3600.to_i
    minutes = (seconds.to_i/60 - hours * 60).to_i
    sprintf("%02d:%02d", hours, minutes)
	end

end
