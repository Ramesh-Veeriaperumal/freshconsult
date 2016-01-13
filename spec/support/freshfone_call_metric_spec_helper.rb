module FreshfoneCallMetricHelper
	CREATED_AT = 8.minutes.ago(Time.zone.now)
	
	def setup_freshfone_call_metrics_attributes
		create_freshfone_call
		@freshfone_call.update_attributes({:created_at => CREATED_AT})
		@call_metrics = @freshfone_call.call_metrics
		params = {
			:ringing_at => 2.minutes.since(@freshfone_call.created_at),
			:hangup_at => 5.minutes.since(@freshfone_call.created_at),
			:answered_at => 3.minutes.since(@freshfone_call.created_at)
		}
		@call_metrics.update_states(params)
	end

	def create_freshfone_call_metrics_only_with_ringing_at
		create_freshfone_call
		@freshfone_call.update_attributes({:created_at => CREATED_AT})
		@call_metrics = @freshfone_call.call_metrics
		params = {
			:ringing_at => 2.minutes.since(@freshfone_call.created_at)
		}
		@call_metrics.update_states(params)
	end

	def mock_call_metrics_attricbutes(call = @freshfone_call)
		call.update_attributes({:created_at => CREATED_AT})
		call.save
		@call_metrics = call.call_metrics
		params = {
			:ringing_at => 2.minutes.since(@freshfone_call.created_at),
			:hangup_at => 5.minutes.since(@freshfone_call.created_at),
			:answered_at => 3.minutes.since(@freshfone_call.created_at)
		}
		@call_metrics.update_states(params)
	end
end