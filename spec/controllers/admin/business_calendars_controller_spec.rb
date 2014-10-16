require 'spec_helper'

describe Admin::BusinessCalendarsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    business_hours = FactoryGirl.build(:business_calendars,:name=>"created by #{Faker::Name.name}", :description=>Faker::Lorem.sentence(2),:account_id=>@account.id)
    business_hours.save(validate: false)
    @test_business_hours=business_hours
  end

  before(:each) do
    log_in(@agent)
  end

  it "should go to the index page" do
    get 'index'
    response.should render_template "admin/business_calendars/index"
    response.body.should =~ /Business Hours/
  end

  it "should go to new business hours page" do
    get 'new'
    response.should render_template "admin/business_calendars/new"
    response.body.should =~ /Business Hours/
  end

  it "should create new business hours" do
    business_hours_name="created by #{Faker::Name.name}"
    post 'create' , :business_calenders => {:name=>business_hours_name, :description=>Faker::Lorem.sentence(2), :time_zone=>"International Date Line West", :fullweek=>"false", :weekdays=>["1", "2", "3", "4", "5"].to_json, :holiday_data=>[["May 27", "gfgf"]].to_json},:Monday=>"1",
      :time=>{"morning_1"=>"8:00", "evening_1"=>"5:00", "morning_2"=>"8:00", "evening_2"=>"5:00", "morning_3"=>"8:00", "evening_3"=>"5:00", "morning_4"=>"8:00", "evening_4"=>"5:00", "morning_5"=>"8:00", "evening_5"=>"5:00"},
      :morning=>{"range_1"=>"am", "range_2"=>"am", "range_3"=>"am", "range_4"=>"am", "range_5"=>"am"},
      :evening=>{"range_1"=>"pm", "range_2"=>"pm", "range_3"=>"pm", "range_4"=>"pm", "range_5"=>"pm"},
      :business_time_data=>{:working_hours=>
                            {"1"=>{"beginning_of_workday"=>"3:00 pm", "end_of_workday"=>"12:00 am"},
                             "2"=>{"beginning_of_workday"=>"3:00 pm", "end_of_workday"=>"12:00 am"},
                             "3"=>{"beginning_of_workday"=>"3:00 pm", "end_of_workday"=>"12:00 am"},
                             "4"=>{"beginning_of_workday"=>"8:00 am", "end_of_workday"=>"5:00 pm"},
                             "5"=>{"beginning_of_workday"=>"8:00 am", "end_of_workday"=>"5:00 pm"},
                             "6"=>{"beginning_of_workday"=>"", "end_of_workday"=>""},
                             "0"=>{"beginning_of_workday"=>"", "end_of_workday"=>""}}},
      :Tuesday=>"2", :Wednesday=>"3", :Thursday=>"4", :Friday=>"5",
      :holiday=>{"date(1i)"=>"2014", "date(2i)"=>"5", "date(3i)"=>"27", "name"=>""}

    @account.business_calendar.find_by_name(business_hours_name).should_not be_nil

  end

  it "should go to edit page of business hours" do
    get 'edit', :id=>@test_business_hours.id
    response.should render_template "admin/business_calendars/edit"
    response.body.should =~ /Business Hours/
  end

  it "should update the business calendar" do
    business_hours_name="Edited by #{Faker::Name.name}"
    put 'update' , :business_calenders => {:name=>business_hours_name, :description=>Faker::Lorem.sentence(2), :time_zone=>"International Date Line West", :fullweek=>"true", :weekdays=>["1", "2", "3", "4", "5"].to_json, :holiday_data=>[["May 27", "gfgf"]].to_json},:Monday=>"1",
      :time=>{"morning_1"=>"8:00", "evening_1"=>"5:00", "morning_2"=>"8:00", "evening_2"=>"5:00", "morning_3"=>"8:00", "evening_3"=>"5:00", "morning_4"=>"8:00", "evening_4"=>"5:00", "morning_5"=>"8:00", "evening_5"=>"5:00"},
      :morning=>{"range_1"=>"am", "range_2"=>"am", "range_3"=>"am", "range_4"=>"am", "range_5"=>"am"},
      :evening=>{"range_1"=>"pm", "range_2"=>"pm", "range_3"=>"pm", "range_4"=>"pm", "range_5"=>"pm"},
      :business_time_data=>{:working_hours=>
                            {"1"=>{"beginning_of_workday"=>"8:00 am", "end_of_workday"=>"5:00 pm"},
                             "2"=>{"beginning_of_workday"=>"8:00 am", "end_of_workday"=>"5:00 pm"},
                             "3"=>{"beginning_of_workday"=>"8:00 am", "end_of_workday"=>"5:00 pm"},
                             "4"=>{"beginning_of_workday"=>"8:00 am", "end_of_workday"=>"5:00 pm"},
                             "5"=>{"beginning_of_workday"=>"8:00 am", "end_of_workday"=>"5:00 pm"},
                             "6"=>{"beginning_of_workday"=>"", "end_of_workday"=>""},
                             "0"=>{"beginning_of_workday"=>"", "end_of_workday"=>""}}},
      :Tuesday=>"2", :Wednesday=>"3", :Thursday=>"4", :Friday=>"5",
      :holiday=>{"date(1i)"=>"2014", "date(2i)"=>"5", "date(3i)"=>"27", "name"=>""},:id=>@test_business_hours.id

    @account.business_calendar.find_by_id(@test_business_hours.id).name.should_not be_eql(@test_business_hours.name)
  end

  it "should delete the business calendar" do
    business_hours = FactoryGirl.build(:business_calendars,:name=>"created by #{Faker::Name.name}", :description=>Faker::Lorem.sentence(2),:account_id=>@account.id)
    business_hours.save(validate: false)
    delete :destroy, {:id=>business_hours.id}
    @account.business_calendar.find_by_id(business_hours.id).should be_nil
  end

  #cases when feature is disabled

  it "should go to default business hour edit page " do
    @account.features.multiple_business_hours.destroy
    default_id=@account.business_calendar.default.first.id
    get 'index'
    response.should redirect_to "/admin/business_calendars/#{default_id}/edit"
    @account.features.multiple_business_hours.create
  end

  it "should go to default business hour edit page while creating new hour" do
    @account.features.multiple_business_hours.destroy
    default_id=@account.business_calendar.default.first.id
    get 'new'
    response.should redirect_to "/admin/business_calendars/#{default_id}/edit"
    @account.features.multiple_business_hours.create
  end

  it "should not destroy default business hour" do
    delete :destroy, {:id=>@account.business_calendar.default.first.id}
    session["flash"][:notice].should eql "The Business Calendar could not be deleted"
    response.should redirect_to('/admin/business_calendars')
  end

end
