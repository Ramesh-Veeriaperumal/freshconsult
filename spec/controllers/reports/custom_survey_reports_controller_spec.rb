require 'spec_helper'

describe Reports::CustomSurveyReportsController do
	# integrate_views
  	setup :activate_authlogic
  	self.use_transactional_fixtures = false

  	before(:all) do

  	end

  	AGENT_ALL_URL_REF = 'a'
	GROUP_ALL_URL_REF = 'g'
	RATING_ALL_URL_REF = 'r'

	before(:each) do
		login_admin
		@ticket = @account.tickets.first
	end

	it "should display reports" do 
		active_survey = @account.custom_surveys.first
		survey_handle= CustomSurvey::SurveyHandle.create_handle_for_notification(@ticket,EmailNotification::PREVIEW_EMAIL_VERIFICATION,active_survey.id,true,false)

		test_result = survey_handle.create_survey_result(CustomSurvey::Survey::EXTREMELY_HAPPY)

		default_params = {:survey_id=>active_survey.id, :start_date=>active_survey.created_at, :end_date=>active_survey.updated_at}
		get :index , default_params
		response.body.should =~ /SurveyReportData/
		response.body.should =~ /customerRatingsStyle/
		response.body.should =~ /surveysList/
	end

	it "should generate reports list" do 
		active_survey = @account.custom_surveys.first
		default_params = {:survey_id=>active_survey.id, :start_date=>active_survey.created_at, :end_date=>active_survey.updated_at}
		get :reports , {survey_id: active_survey.id, group_id:GROUP_ALL_URL_REF, agent_id: AGENT_ALL_URL_REF,date_range: Date.yesterday.to_time.to_i.to_s << " - " << Date.today.to_time.to_i.to_s}		
		response.should be_success
	end

	it "should generate remarks" do
		active_survey = @account.custom_surveys.find(:all , :conditions => {:active => true}).first
		default_params = {:survey_id=>active_survey.id, :start_date=>active_survey.created_at, :end_date=>active_survey.updated_at}
		get :remarks , {survey_id: active_survey.id, group_id: GROUP_ALL_URL_REF, agent_id: AGENT_ALL_URL_REF, rating: RATING_ALL_URL_REF ,date_range:'1427740200-1430332200' }		
		response.should be_success
		response.body.should =~ /questions_result/
		response.body.should =~ /group_wise_report/
		response.body.should =~ /survey_report_summary/
		response.body.should =~ /remarks/
	end

end