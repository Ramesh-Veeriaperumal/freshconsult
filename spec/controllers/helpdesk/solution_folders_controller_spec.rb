require 'spec_helper'

describe Solution::FoldersController do
  # integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @user = create_dummy_customer
    time = (Time.now.to_f*1000).to_i
    @now = (Time.now.to_f*1000).to_i
    @test_category = create_category( {:name => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", :is_default => false} )       

    @test_folder = create_folder( {:name => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", :visibility => 1,
     :category_id => @test_category.id } )
    @test_folder2 = create_folder( {:name => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", :visibility => 1,
     :category_id => @test_category.id } )
  end

  before(:each) do
    login_admin
  end

  it "should redirect to category show if folder index is hit" do 
    get :index, :category_id => @test_category.id
    response.should redirect_to(solution_category_url(@test_category.id))
  end

  it "should render a show page of a folder" do
    get :show, :id => @test_folder.id, :category_id => @test_category.id
    response.body.should =~ /#{@test_folder.name}/
    response.should render_template("solution/folders/show")
  end

  it "should redirect user with no privilege to login" do 
    session = UserSession.find
    session.destroy
    log_in(@user)
    get :show, :id => @test_folder.id, :category_id => @test_category.id
    flash[:notice] =~ I18n.t(:'flash.general.need_login')  
    UserSession.find.destroy
  end

  it "should redirect to support folder show if user is logged out" do     
    session = UserSession.find
    session.destroy
    get :show, :id => @test_folder.id, :category_id => @test_category.id, :format => nil 
    response.should redirect_to(support_solutions_folder_path(@test_folder))
  end

  it "should reorder folders" do
    category = create_category( {:name => "new category #{Faker::Name.name}", :description => "#{Faker::Lorem.sentence(3)}", :is_default => false} )   
    position_arr = (1..4).to_a.shuffle
    reorder_hash = {}
    for i in 0..3
      folder = create_folder( {:name => "new folder #{Faker::Name.name}", :description => "#{Faker::Lorem.sentence(3)}", :visibility => 1,
                  :category_id => category.id } )
      reorder_hash[folder.id] = position_arr[i] 
    end
    put :reorder, :category_id => category.id, :reorderlist => reorder_hash.to_json
    category.folders.each do |current_folder|
      current_folder.position.should be_eql(reorder_hash[current_folder.id])
    end    
  end  
  
  it "should render edit if folder update fails" do 
    put :update, :id => @test_folder.id, :category_id => @test_category.id,
      :solution_folder => { :name => nil,
                            :description => "#{Faker::Lorem.sentence(3)}"
                          }
    response.body.should =~ /Edit Folder/    
    response.should render_template("solution/folders/edit")
  end    

  it "should not allow restricted agent" do
    UserSession.find.destroy
    restricted_agent = add_agent(@account, { :name => Faker::Name.name,
                                            :email => Faker::Internet.email,
                                            :active => 1,
                                            :role => 1,
                                            :agent => 1,                                            
                                            :privileges => 1
                                            })
    log_in(restricted_agent)
    get :show, :id => @test_folder.id, :category_id => @test_category.id
    response.status.should eql "302 Found"
    session["flash"][:notice].should eql I18n.t(:'flash.general.access_denied')
    UserSession.find.destroy    
  end

  it "should render a new folder form" do 
    get :new, :category_id => @test_category.id
    response.body.should =~ /Add Folder/
    response.should render_template("solution/folders/new")    
  end  

  it "should create a new solution category folder" do
    now = (Time.now.to_f*1000).to_i
    name = Faker::Name.name
    post :create, {:solution_folder => {:name => "#{name}", :description => "#{Faker::Lorem.sentence(3)}", :visibility => 1},
        :category_id => @test_category.id }
    RSpec.configuration.account.folders.find_by_name(name).should be_an_instance_of(Solution::Folder)    
  end

  it "should redirect to new page if folder create fails" do 
    post :create, :solution_folder => {:description => "#{Faker::Lorem.sentence(3)}"}, :category_id => @test_category
    response.body.should =~ /Add Folder/
    response.should render_template("solution/folders/new")    
  end

  it "should edit a solution folder" do
    get :edit, :id => @test_folder.id, :category_id => @test_category.id
    response.body.should =~ /Edit Folder/
    name = Faker::Name.name
    put :update, :id => @test_folder.id, 
      :solution_folder => 
        { :name => "#{name}",
          :description => "#{Faker::Lorem.sentence(3)}",
          :visibility => 1
        },
      :category_id => @test_category.id
    RSpec.configuration.account.folders.find_by_name("#{name}").should be_an_instance_of(Solution::Folder)
    response.should redirect_to(solution_category_path(@test_category.id))
  end

  it "should not edit a default folder" do 
    default_category = RSpec.configuration.account.solution_categories.find_by_is_default(true)
    get :edit, :id => default_category.folders.first.id, :category_id => default_category.id
    session["flash"][:notice].should eql I18n.t(:'folder_edit_not_allowed')
  end  

  it "should delete a solution categories folder" do
    delete :destroy, :id => @test_folder.id, :category_id => @test_category.id
    RSpec.configuration.account.folders.find_by_name("#{@test_folder.name}").should be_nil
    response.should redirect_to(solution_category_path(@test_category))    
  end

end
