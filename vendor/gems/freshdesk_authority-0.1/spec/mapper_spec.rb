require File.dirname(__FILE__) + '/spec_helper'

describe Authority::Mapper do
  before(:each) do
    @resources = [ :project, :following, :deployment ]
    @project_actions = [ :new, :create, :edit, :update, :destroy ]
    @actions = []
  end
  
  describe "#resource" do
    it "should have a key for each resource" do
      ABILITIES.each do |resource, privileges|
        @resources.include?(resource).should eql true
      end
    end
    
    it "should have added the correct actions under each resource" do
      ABILITIES.each do |resource, privileges|
        @actions = []
        if resource == :project
          privileges.each do |privilege|
            @actions << (privilege.action)            
          end
          @actions.should  =~ @project_actions
          
        elsif resource == :follow || resource == :deployment
          privileges.each do |privilege|
            @actions << privilege.action
          end
          @actions.should =~ [:all]
        end
        
      end # end of each
    end # end of it
  end # end of describe
end