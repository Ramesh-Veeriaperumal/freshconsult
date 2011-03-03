require 'spec_helper'

describe Helpdesk::TicketState do
  before(:each) do
    @valid_attributes = {
      :opened_at => Time.now,
      :pending_since => Time.now,
      :resolved_at => Time.now,
      :closed_at => Time.now,
      :first_asigned_at => Time.now,
      :assigned_at => Time.now,
      :first_response_time => Time.now,
      :requester_responded_at => Time.now,
      :agent_responded_at => Time.now
    }
  end

  it "should create a new instance given valid attributes" do
    Helpdesk::TicketState.create!(@valid_attributes)
  end
end
