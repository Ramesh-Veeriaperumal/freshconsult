require 'spec_helper'

describe TicketField do
  before(:each) do
    @valid_attributes = {
      :account_id => 1,
      :name => "value for name",
      :lable => "value for lable",
      :lable_in_portal => "value for lable_in_portal",
      :description => "value for description",
      :active => false,
      :field_type => "value for field_type",
      :position => 1,
      :required => false,
      :visible_in_portal => false,
      :editable_in_portal => false,
      :required_in_portal => false,
      :flexifield_def_entry_id => 1
    }
  end

  it "should create a new instance given valid attributes" do
    TicketField.create!(@valid_attributes)
  end
end
