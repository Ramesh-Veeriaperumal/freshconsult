require 'spec_helper'

describe Widget do
  before(:each) do
    @valid_attributes = {
      :widget_code => "value for widget_code"
    }
  end

  it "should create a new instance given valid attributes" do
    Widget.create!(@valid_attributes)
  end
end
