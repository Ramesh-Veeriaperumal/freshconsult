require 'spec_helper'

describe SurveyScore do
  before(:each) do
    @valid_attributes = {
      :account_id => 1,
      :surveyable_id => 1,
      :surveyable_type => "value for surveyable_type",
      :customer_id => 1,
      :agent_id => 1,
      :resolution_speed => 1,
      :customer_rating => 1,
      :score => 1
    }
  end

  it "should create a new instance given valid attributes" do
    SurveyScore.create!(@valid_attributes)
  end
end
