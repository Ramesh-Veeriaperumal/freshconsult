require 'spec_helper'

describe SurveyHandle do
  before(:each) do
    @valid_attributes = {
      :account_id => 1,
      :surveyable_id => 1,
      :surveyable_type => "value for surveyable_type",
      :id_token => "value for id_token"
    }
  end

  it "should create a new instance given valid attributes" do
    SurveyHandle.create!(@valid_attributes)
  end
end
