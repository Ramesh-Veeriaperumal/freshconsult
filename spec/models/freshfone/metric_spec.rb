require 'spec_helper'
load 'spec/support/freshfone_call_metric_spec_helper.rb'
include FreshfoneCallMetricHelper
RSpec.describe Freshfone::CallMetric do 
	self.use_transactional_fixtures = false
	before(:each) do
		create_test_freshfone_account
	end

	it 'should create new freshfone call metric' do
		create_freshfone_call
		expect(@freshfone_call.call_metrics).not_to be_nil
	end

	it 'should update freshfone call metric attributes' do
		create_freshfone_call
		@call_metrics = @freshfone_call.call_metrics
		params = {
			:ringing_at => 2.minutes.since(@freshfone_call.created_at),
			:hangup_at => 5.minutes.since(@freshfone_call.created_at),
			:answered_at => 3.minutes.since(@freshfone_call.created_at)
		}
		@call_metrics.update_states(params).should be true
	end

	it 'should update freshfon call metrics talk time and total ring time' do
		create_freshfone_call
		@call_metrics = @freshfone_call.call_metrics
		params = {
			:ringing_at => 2.minutes.since(@freshfone_call.created_at),
			:hangup_at => 5.minutes.since(@freshfone_call.created_at),
			:answered_at => 3.minutes.since(@freshfone_call.created_at)
		}
		@call_metrics.update_states(params)
		@call_metrics.calculate_and_update_states
		@call_metrics.talk_time.should be 120
		@call_metrics.total_ringing_time.should be 60
	end

	it 'should update call work time' do
		setup_freshfone_call_metrics_attributes
		@call_metrics.calculate_and_update_states
		@call_metrics.update_call_work_duration
		@call_metrics.call_work_time.should be > 180
		@call_metrics.handle_time.should be > 300
	end

	it 'should not update existing freshfone call metric attributes' do
		setup_freshfone_call_metrics_attributes
		ringing_at = 5.minutes.since(@freshfone_call.created_at)
		params = { :ringing_at => ringing_at }
		@call_metrics.update_states(params)
		expect(@call_metrics.ringing_at).not_to eq(ringing_at)
	end

	it 'should not update talk time, total ringing time and handle_time' do 
		create_freshfone_call_metrics_only_with_ringing_at
		@call_metrics.calculate_and_update_states
		@call_metrics.talk_time.should be nil
		@call_metrics.total_ringing_time.should be nil
		@call_metrics.handle_time.should be 0
	end

	
end
