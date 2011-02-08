require 'spec_helper'

describe BusinessCalendar do
  before(:each) do
    @valid_attributes = {
      :account_id => 1,
      :business_time_data => "value for business_time_data",
      :holiday_data => "value for holiday_data"
    }
  end

  it "should create a new instance given valid attributes" do
    BusinessCalendar.create!(@valid_attributes)
  end
end
