# module FreshcallerCallTestHelper

# 	def build_call(params = {})
# 		test_call = FactoryGirl.build(:freshcaller_call,
# 								:account_id => @account_id,
# 								:fc_call_id => params[:fc_call_id] || rand(2..500),
# 								:recording_status => params[:recording_status] || Freshcaller::Call::RECORDING_STATUS_HASH[:completed])
# 		test_call
# 	end

# 	def link_and_create(freshcaller_call_object, notable_object)
# 		freshcaller_call_object.notable = notable_object
# 		freshcaller_call_object.save
# 	end
# end