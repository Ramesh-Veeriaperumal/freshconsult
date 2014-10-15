require 'spec_helper'

RSpec.describe Freshfone::CallHistoryController do
	self.use_transactional_fixtures = false
	before(:each) do
		create_test_freshfone_account
		api_login
	end

	it "should get call history with agent" do
		create_freshfone_customer_call
		get :custom_search, { "format" => "json", "wf_order"=>"created_at", "wf_order_type"=>"desc", 
                          "page"=>"1", "number_id"=>@number.id }
    	json_response.should include("calls","freshfone_numbers")
    	json_response["calls"].each do |result|
    		result.should include("call")
    		result["call"].should include("id","call_cost","call_duration","call_sid","call_type","call_status","currency","recording_url","location","created_at","children_count","caller_number","agent")
    		result["call"]["agent"].should include("id","name")
        result["call"]["customer"].should include("name")
    	end
    	json_response["freshfone_numbers"][0].should include("number")
    	json_response["freshfone_numbers"][0]["number"].should include("id","display_number")
	end

	it "should get children history for a call" do
		create_call_family
		get :children, {"format" => "json", "id" => @parent_call, "number_id" => @number.id}
		json_response.should include("calls")
    	json_response["calls"].each do |result|
    		result.should include("call")
    		result["call"].should include("id","call_cost","call_duration","call_sid","call_type","call_status","currency","recording_url","location","created_at","children_count","caller_number","agent")
    		result["call"]["agent"].should include("id","name")
    	end
	end
end