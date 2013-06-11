require File.dirname(__FILE__) + '/spec_helper'

describe Authority::Privilege do
  before(:each) do
    load_schema_and_data
    
    @john.privilege_list = [ :create_project ]
    @john.save
   
    @privilege = Authority::Privilege.new(:project, :create_project)
    
    @privilege_only_action = Authority::Privilege.new(
      :project,
      :create_project,
      { :action => :create }
    )
    @privilege_only_owned_by = Authority::Privilege.new(
      :project,
      :edit_project,
      { :owned_by => { :scoper => :projects} }
    )
    @privilege_owned_by_with_find_by = Authority::Privilege.new(
      :project,
      :edit_project,
      { 
        :owned_by => { :scoper => :projects, :find_by => :name } 
      }
    )
    @privilege_action_and_owned_by = Authority::Privilege.new(
      :project,
      :create_project,
      { 
        :action => :create,
        :owned_by => { :scoper => :projects } 
      }
    )
    @privilege_action_and_owned_by_with_find_by = Authority::Privilege.new(
      :project,
      :edit_project,
      { 
        :action => :edit,
        :owned_by => { :scoper => :projects, :find_by => :name } 
      }
    )
  end
  
  describe "#resource" do
    it "shoudl return the correct resource" do
      @privilege.resource.should eql :project
      @privilege_only_action.resource.should eql :project
      @privilege_only_owned_by.resource.should eql :project
      @privilege_owned_by_with_find_by.resource.should eql :project
      @privilege_action_and_owned_by.resource.should eql :project
      @privilege_action_and_owned_by_with_find_by.resource.should eql :project
    end
  end
  
  describe "#name" do
    it "should return the correct privilege name" do
      @privilege.name.should eql :create_project
      @privilege_only_action.name.should eql :create_project
      @privilege_only_owned_by.name.should eql :edit_project
      @privilege_owned_by_with_find_by.name.should eql :edit_project
      @privilege_action_and_owned_by.name.should eql :create_project
      @privilege_action_and_owned_by_with_find_by.name.should eql :edit_project
    end
  end
  
  describe "#action" do
    it "should return :all since no argument was passed" do
      @privilege.action.should eql :all
      @privilege_only_owned_by.action.should eql :all
      @privilege_owned_by_with_find_by.action.should eql :all
    end
    
    it "should return correct action name" do
      @privilege_only_action.action.should eql :create
      @privilege_action_and_owned_by.action.should eql :create
      @privilege_action_and_owned_by_with_find_by.action.should eql :edit
    end
  end
  
  describe "#owned_by" do
    it "should return false since no argument was passed" do
      @privilege.owned_by.should eql false
      @privilege_only_action.owned_by.should eql false
    end
    
    it "should not return false since owned_by was passed" do
      @privilege_only_owned_by.owned_by.should_not eql false      
      @privilege_owned_by_with_find_by.owned_by.should_not eql false
      @privilege_action_and_owned_by.owned_by.should_not eql false
      @privilege_action_and_owned_by_with_find_by.owned_by.should_not eql false
    end
    
    it "should return the correct scoper" do
      @privilege_only_owned_by.scoper.should eql :projects
      @privilege_owned_by_with_find_by.scoper.should eql :projects
      @privilege_action_and_owned_by.scoper.should eql :projects
      @privilege_action_and_owned_by_with_find_by.scoper.should eql :projects
    end
    
    it "should return default attribute :id since no :find_by was passed" do
      @privilege_only_owned_by.attribute.should eql :id
      @privilege_action_and_owned_by.attribute.should eql :id
    end
    
    it "should return correct attribure" do
      @privilege_owned_by_with_find_by.attribute.should eql :name
      @privilege_action_and_owned_by_with_find_by.attribute.should eql :name
    end
  end
  
  # describe "#allowed?" do
 #    it "should return true if allowed" do
 #      @privilege.allowed?(@john, @account, { :id => 1 }).should eql true
 #      @privilege_only_action.allowed?(@john, @account, { :id => 1 }).should eql true
 #      @privilege_only_owned_by.allowed?(@john, @account, { :id => 1 }).should eql true
 #      @privilege_owned_by_with_find_by.allowed?(@john, @account, { :id => 1, :name => "Authority 1" }).should eql true
 #      @privilege_action_and_owned_by.allowed?(@john, @account, { :id => 1 }).should eql true
 #      @privilege_action_and_owned_by_with_find_by.allowed?(@john, @account, { :id => 1, :name => "Authority 1" }).should eql true
 #    end 
 #  end
end
