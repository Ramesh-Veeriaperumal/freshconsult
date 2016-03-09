require 'spec_helper'

describe Admin::FreshfoneController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    create_test_freshfone_account
    @request.host = @account.full_domain
    log_in(@agent)
  end

  it 'should redirect to numbers on index action' do
    get :index
    response.should redirect_to('/admin/phone/numbers')
  end

  it 'should return all available phone numbers on search' do
    get :available_numbers, {"search_options"=>{"type"=>"local", 
                    "in_region"=>"", "contains"=>""}, "country"=>"US"}
    assigns[:search_results].count.should be_eql(30)
    assigns[:search_results].map{|result| result[:iso_country]}.uniq.should be_eql(["US"])
    response.should render_template ("admin/freshfone/numbers/_freshfone_available_numbers")
  end

  it 'should return all available phone numbers on search with no search options' do
    get :available_numbers, {"country"=>"US"}
    assigns[:search_results].count.should be_eql(30)
    assigns[:search_results].map{|result| result[:iso_country]}.uniq.should be_eql(["US"])
    response.should render_template ("admin/freshfone/numbers/_freshfone_available_numbers")
  end

  it 'should not return any results when invalid pattern is provided for search' do
    get :available_numbers, {"search_options"=>{"type"=>"local", 
              "in_region"=>"", "contains"=>"123 321312"}, "country"=>"US"}
    assigns[:search_results].should be_empty
  end

  it 'should redirect to numbers on toggle_freshfone action' do
    get :toggle_freshfone
    response.should redirect_to('/admin/phone/numbers')
  end

  it 'should render index page when onboarding feature is not enabled' do
    @account.freshfone_numbers.destroy_all
    @account.features.freshfone.destroy
    @account.features.freshfone_conference.destroy
    get :index
    expect(response).to render_template(:index)
  end

  it 'should render index page when onboarding feature is not enabled' do
    @account.freshfone_numbers.destroy_all
    @account.features.freshfone.destroy
    @account.features.freshfone_conference.destroy
    @account.launch(:freshfone_onboarding)
    get :index
    expect(response).to render_template(:index)
    @account.rollback(:freshfone_onboarding)
  end

end