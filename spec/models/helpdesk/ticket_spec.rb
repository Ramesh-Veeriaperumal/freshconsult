require 'spec_helper'

describe Helpdesk::Ticket do
  before(:each) do
    @valid_attributes = {
      
    }
  end

  it "should create a new instance given valid attributes" do
    Helpdesk::Ticket.create!(@valid_attributes)
  end
end
