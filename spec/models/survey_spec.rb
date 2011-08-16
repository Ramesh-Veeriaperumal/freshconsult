require 'spec_helper'

describe Survey do
  before(:each) do
    @valid_attributes = {
      :account_id => 1,
      :link_text => "value for link_text",
      :send_while => 1
    }
  end

  it "should create a new instance given valid attributes" do
    Survey.create!(@valid_attributes)
  end
end
