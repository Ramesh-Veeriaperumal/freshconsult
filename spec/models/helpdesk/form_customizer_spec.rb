require 'spec_helper'

describe Helpdesk::FormCustomizer do
  before(:each) do
    @valid_attributes = {
      :name => "value for name",
      :json_data => "value for json_data",
      :account_id => 1
    }
  end

  it "should create a new instance given valid attributes" do
    Helpdesk::FormCustomizer.create!(@valid_attributes)
  end
end
