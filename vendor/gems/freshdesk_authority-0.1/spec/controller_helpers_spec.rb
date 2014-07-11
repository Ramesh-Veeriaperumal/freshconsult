require File.dirname(__FILE__) + '/spec_helper'

describe Authority::Rails::ControllerHelpers do
    before(:each) do  
      load_schema_and_data
      
      @derrick.privilege_list = [ :create_project, :edit_project, :follow_project ]
      @derrick.save
       
      @params = HashWithIndifferentAccess.new(:controller => "projects")
      @controller_class = Class.new
      @controller = @controller_class.new

      stub(@controller).params { @params }
      stub(@controller).current_user { @derrick }
      stub(@controller).current_account { @account }
      mock(@controller_class).append_before_filter(:check_privilege)
      mock(@controller_class).helper_method(:privilege?)
      
      @controller_class.send(:include, Authority::Rails::ControllerHelpers)          
    end
    
    describe "#privilege?" do
      it "should return true for privilges associated with user" do
        @controller.privilege?(:create_project).should eql true
        @controller.privilege?(:edit_project).should eql true
        @controller.privilege?(:follow_project).should eql true
      end
      
      it "should return false for privilges not associated with user" do
        @controller.privilege?(:destroy_project).should eql false
      end
      
      it "should return true if user own's the object but if he does not have the privilege" do
        @controller.privilege?(:destroy_project, @project_2).should eql true
      end
      
      it "should return false if user does not own's the object or have the privilege" do
        @controller.privilege?(:destroy_project, @project_1).should eql false
      end
    end
    
    describe "#authorized?" do
      it "should return true if user can access resource/action" do
        @params.merge!(:action => "update", :id => 1)   
        @controller.authorized?.should eql true
        @params.merge!(:action => "edit", :id => 1)
        @controller.authorized?.should eql true
        @params.merge!(:action => "edit", :id => 2)   
        @controller.authorized?.should eql true
        @params.merge!(:action => "update", :id => 2)   
        @controller.authorized?.should eql true
        @params.merge!(:action => "destroy", :id => 1)   
        @controller.authorized?.should eql true
      end
    
      it "should return false if user cannot access resource/action" do
        @params.merge!(:action => "destroy", :id => 2)   
        @controller.authorized?.should eql false
        @params.merge!(:controller => "deployment", :action => "deploy", :id => 2)
        @controller.authorized?.should eql false        
      end
        
      it "should return true for any action of following controller" do
        @params.merge!(:controller => "following", :action => "sample_action") 
        @controller.authorized?.should eql true
      end
    end
end