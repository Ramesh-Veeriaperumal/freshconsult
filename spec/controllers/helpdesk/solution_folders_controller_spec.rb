require 'spec_helper'

describe Solution::FoldersController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    time = (Time.now.to_f*1000).to_i
    @now = (Time.now.to_f*1000).to_i
    @test_category = create_category( {:name => "new category #{@now}", :description => "new category", :is_default => false} )
    @test_folder = create_folder( {:name => "new folder #{@now}", :description => "new folder", :visibility => 1,
     :category_id => @test_category.id } )
  end

  before(:each) do
    log_in(@user)
  end

  it "should create a new solution category folder" do
    now = (Time.now.to_f*1000).to_i
    post :create, {:solution_folder => {:name => "New folder #{now}", :description => "New folder #{now}", :visibility => 1},
        :category_id => @test_category.id }
    @account.folders.find_by_name("New folder #{now}").should be_an_instance_of(Solution::Folder)
  end

  it "should edit a solution categories folder" do
    get :edit, :id => @test_folder.id, :category_id => @test_category.id
    response.body.should =~ /Edit Folder/
    put :update, :id => @test_folder.id, 
      :solution_folder => 
        { :name => "New folder #{@now}",
          :description => "Testing Category Folder",
          :visibility => 1
        },
      :category_id => @test_category.id
    @account.folders.find_by_name("New folder #{@now}").should be_an_instance_of(Solution::Folder)
  end

  it "should delete a solution categories folder" do
    delete :destroy, :id => @test_folder.id, :category_id => @test_category.id
    @account.folders.find_by_name("New folder #{@now}").should be_nil
  end

end
