require 'spec_helper'

describe Wf::FilterController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    login_admin
  end

  it "should list only accessible filters in index action" do
    get :index
    filters = scoper.my_ticket_filters(get_admin)
    filters.each do |filter|
      response.body.should =~ /#{filter.name}/
    end
  end

  it "should update a filter" do
    filter = create_filter(WfFilterHelper::PARAMS1)
    @request.cookies['filter_name'] = filter.id
    params = WfFilterHelper::PARAMS2.merge('id' => filter.id)
    put :update_filter, params
    filter.reload
    check_filter_equality filter, params
  end

  it "should save a new filter" do
    filter_name = Faker::Name.name
    params = WfFilterHelper::PARAMS1.merge('filter_name' => filter_name)
    post :save_filter, params
    filter = scoper.find_by_name(filter_name)
    check_filter_equality filter, params
  end

  it "should delete a filter" do
    filter = create_filter(WfFilterHelper::PARAMS1)
    delete :delete_filter, :id => filter.id
    expect { filter.reload }.to raise_error(ActiveRecord::RecordNotFound)
    flash[:notice].should be_eql(I18n.t(:'flash.filter.delete_success'))
  end

  it "should deny permission for users who doesnt have access" do
    user = add_agent(@account, {:email => Faker::Internet.email, :active => 1, :privileges => '0'})
    log_in(user)

    params = WfFilterHelper::PARAMS1
    params[:visibility]['user_id'] = get_admin.id
    filter = create_filter(params)
    
    @request.cookies['filter_name'] = filter.id
    put :update_filter, WfFilterHelper::PARAMS1.merge('id' => filter.id)
    flash[:notice].should be_eql(I18n.t(:'flash.general.access_denied'))

    delete :delete_filter, :id => filter.id
    flash[:notice].should be_eql(I18n.t(:'flash.general.access_denied'))
  end

  it "should not save a new filter with errors" do
    params = WfFilterHelper::PARAMS1.merge('filter_name' => nil)
    post :save_filter, params
    flash[:error].should_not be_nil
  end

  private
  
    def scoper
      @account.ticket_filters
    end

end