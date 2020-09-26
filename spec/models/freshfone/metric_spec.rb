require 'spec_helper'

RSpec.describe Freshfone::CallMetric do 
	self.use_transactional_fixtures = false
	before(:each) do
		create_test_freshfone_account
		@account.features.freshfone_call_metrics.create
	end

	it 'should create new freshfone call metric' do
		create_freshfone_call
		expect(@freshfone_call.call_metrics).not_to be_nil
	end	
end
