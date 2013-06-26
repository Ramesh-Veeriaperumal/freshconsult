require File.dirname(__FILE__) + '/spec_helper'

describe Authority::Rails::ModelHelpers do
  before(:all) do
    load_schema_and_data
  end
  
  it "should be an instance of User" do  
    @derrick.should be_an_instance_of User
    @john.should be_an_instance_of User
  end
  
  it "should return the correct bitmask" do
    @derrick.privileges.to_i.should eql 3
    @john.privileges.to_i.should eql 15
  end
  
  describe "#privilege?" do
    it "should return true if user has the privilege" do
      @derrick.privilege?(:create_project).should eql true
      @derrick.privilege?(:edit_project).should eql true
    
      @john.privilege?(:create_project).should eql true
      @john.privilege?(:edit_project).should eql true
      @john.privilege?(:destroy_project).should eql true
      @john.privilege?(:follow_project).should eql true
    end
  
    it "should return false if user does not have the privilege" do
      @derrick.privilege?(:destroy_project).should eql false
      @derrick.privilege?(:follow_project).should eql false
    
      @john.privilege?(:deploy_project).should eql false
    end
  end
  
  describe "#owns_object?" do
    it "should return false if user does not own the object" do
      @derrick.owns_object?(@project_1).should eql false      
    end
    
    it "should return true if user owns the object" do
      @derrick.owns_object?(@project_2).should eql true    
    end
  end
  
  describe "#abilities" do
    it "should return the correct list of privileges associated with the user" do
      @derrick.abilities.should =~ [:create_project, :edit_project]
      @john.abilities.should =~ [:create_project, :edit_project, :destroy_project, :follow_project]
    end
  end
  
  describe "#union_privileges" do
    it "should give the correct union of privileges" do
      # BAD WAY TO TEST !!
      # This method will be implemented inside the roles model
      # Role objects need to be passed
      # can it be moved out ?
      
      # @derrick.privileges = 3
      # @john.privileges = 15
      union_mask = @derrick.union_privileges([@derrick, @john])
      union_mask.should eql 15
      
      @rose = User.new(
        :name => "rose",
        :account_id => @account,
        :privilege_list => @customer
      )
      @rose.save!
      
      # @derrick.privileges = 3
      # @rose.privileges = 8
      union_mask = @derrick.union_privileges([@derrick, @rose])
      union_mask.should eql 11
    end
  end  
  
end