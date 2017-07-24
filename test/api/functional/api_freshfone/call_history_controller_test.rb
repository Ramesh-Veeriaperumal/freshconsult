require_relative '../../test_helper'

class ApiFreshfone::CallHistoryControllerTest < ActionController::TestCase
	

	def wrap_cname(params)
    	{ call_history: params }
  	end

	def setup 
 		super
    	before_all
	end

	 @@before_all_run = false

	def before_all
		return if @@before_all_run
    	@account.reload
	    @@before_all_run = true
	end

	def test_call_history_export_with_valid_params
		post :export, construct_params(export_format: 'csv' )
		assert_response 202
		response = parse_response @response.body
		assert response["status"] == "started"
	end

	def test_call_history_export_with_all_valid_params
		ApiFreshfone::CallHistoryFilterValidation.any_instance.stubs(:active_freshfone_number).returns(true)
		post :export, construct_params({
			call_type: 'dialed', 
			number: "+12345678900",
			business_hour_call: 'true',
			group_id: 1,
			user_ids: [1,2],
			start_date: "2017-05-30", 
			end_date: "2017-06-30",
			requester_id: 1, 
			company_id: 1,
			export_format: 'csv' })
		assert_response 202
		response = parse_response @response.body
		assert response["status"] == "started"
	end

	def test_call_history_export_with_invalid_group_id
		post :export, construct_params({group_id: "dummy"})
		assert_response 400
		match_json([bad_request_error_pattern('group_id', "It should be a/an Positive Integer", {code: "datatype_mismatch"})])
	end

	def test_call_history_export_with_invalid_business_hour_call
		post :export, construct_params({business_hour_call: "dummy"})
		assert_response 400
		match_json([bad_request_error_pattern('business_hour_call', "It should be a/an Boolean", {code: "datatype_mismatch"})])
	end

	def test_call_history_export_with_invalid_user_ids
		post :export, construct_params({user_ids: "dummy"})
		assert_response 400
		match_json([bad_request_error_pattern('user_ids', "Value set is of type String.It should be a/an Array", {code: "datatype_mismatch"})])
	end

	def test_call_history_export_status_with_valid_params
		post :export, construct_params(export_format: 'csv' )
		assert_response 202
		response = parse_response @response.body
		assert response["status"] == "started"
		id = response["id"]
		get :export_status, controller_params(:id => id)
		assert_response 200
		response = parse_response @response.body
		assert response["status"] == "started"
	end
end