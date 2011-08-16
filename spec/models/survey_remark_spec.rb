require 'spec_helper'

describe SurveyRemark do
  before(:each) do
    @valid_attributes = {
      :survey_score_id => 1,
      :note_id => 1
    }
  end

  it "should create a new instance given valid attributes" do
    SurveyRemark.create!(@valid_attributes)
  end
end
