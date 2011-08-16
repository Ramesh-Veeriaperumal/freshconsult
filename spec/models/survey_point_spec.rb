require 'spec_helper'

describe SurveyPoint do
  before(:each) do
    @valid_attributes = {
      :survey_id => 1,
      :resolution_speed => 1,
      :customer_mood => 1,
      :score => 1
    }
  end

  it "should create a new instance given valid attributes" do
    SurveyPoint.create!(@valid_attributes)
  end
end
