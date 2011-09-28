require 'spec_helper'

describe DataImport do
  before(:each) do
    @valid_attributes = {
      :import_type => "value for import_type",
      :status => false,
      :account_id => 1
    }
  end

  it "should create a new instance given valid attributes" do
    DataImport.create!(@valid_attributes)
  end
end
