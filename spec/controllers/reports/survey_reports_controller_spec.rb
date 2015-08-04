require 'spec_helper'

describe Reports::SurveyReportsController do
  	setup :activate_authlogic
  	self.use_transactional_fixtures = false

	before(:each) do
		login_admin
	end

	it "should display reports" do 
		active_survey = @account.survey
		default_params = {:survey_id=>active_survey.id, :start_date=>active_survey.created_at, :end_date=>active_survey.updated_at}
		get :index , default_params
		response.should be_success
		response.body.should =~ /Customer Satisfaction Report/

	end

	it "should generate reports list" do 
		get :list
		response.should be_success
	end

	it "generate feedback" do 
		get :feedbacks
		response.should render_template('_feedbacks')
	end

	it "should refresh details" do
		get :refresh_details
		response.should render_template('_refresh_details')
	end
end