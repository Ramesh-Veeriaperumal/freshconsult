require File.dirname(__FILE__) + '/spec_helper'

describe Authority::Bookkeeper do
  
    before(:all) do
      @keeper = Authority::Bookkeeper.new('privileges_test.yml')
    end
    
    describe "#self.load_privileges" do
      it "should return the correct privileges from yaml" do
        test_case = { 
          :create_project   => 0,
          :edit_project     => 1,
          :destroy_project  => 2,
          :follow_project   => 3,
          :deploy_project   => 4 
        } 
        @keeper.load_privileges.should eql test_case
      end  
    end
    
    describe "#self.mapper" do
      it "add new privilege and the save it to yaml with correct id" do
        test_case = { 
          :create_project   => 0,
          :edit_project     => 1,
          :destroy_project  => 2,
          :follow_project   => 3,
          :deploy_project   => 4,
          :new_privilege_1  => 5
        }
        Authority::Authorization::PrivilegeList.privileges_by_name << :new_privilege_1
        @keeper.map(Authority::Authorization::PrivilegeList.privileges_by_name)
        @keeper.load_privileges.should eql test_case
      end
    end
    
    describe "#self.purge" do
      it "should remove the deleted privilege from yaml" do
        test_case = { 
          :create_project   => 0,
          :destroy_project  => 2,
          :follow_project   => 3,
          :deploy_project   => 4,
          :new_privilege_1  => 5 
        }
        Authority::Authorization::PrivilegeList.privileges_by_name.delete(:edit_project)
        @keeper.purge
        @keeper.load_privileges.should eql test_case
      end
    end
    
    describe "#self.mapper" do
      it "when new privilege is added it should add its id should be last index + 1" do
        test_case = { 
          :create_project   => 0,
          :destroy_project  => 2,
          :follow_project   => 3,
          :deploy_project   => 4,
          :new_privilege_1  => 5,
          :new_privilege_2  => 6
         }
        Authority::Authorization::PrivilegeList.privileges_by_name << :new_privilege_2
        @keeper.map(Authority::Authorization::PrivilegeList.privileges_by_name)
        @keeper.load_privileges.should eql test_case
      end
    end
end