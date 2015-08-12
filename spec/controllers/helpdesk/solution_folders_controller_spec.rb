require 'spec_helper'

describe Solution::FoldersController do
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
                                            :role_ids => [@account.roles.find_by_name("Agent").id.to_s]                                         
                                            })
    restricted_agent.privileges = 1
    restricted_agent.save
    log_in(restricted_agent)
    get :show, :id => @test_folder.id, :category_id => @test_category.id
    response.status.should eql 302
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
    @account.folders.find_by_name(name).should be_an_instance_of(Solution::Folder)    
  end

  it "should redirect to new page if folder create fails" do 
    post :create, :solution_folder => {:description => "#{Faker::Lorem.sentence(3)}"}, :category_id => @test_category
    response.body.should =~ /Add Folder/
    response.should render_template("solution/folders/new")    
  end

  it "should edit a solution folder" do# failing in master
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
    @account.folders.find_by_name("#{name}").should be_an_instance_of(Solution::Folder)
    response.should redirect_to(solution_folder_path(@test_folder.id))
  end

  it "should not edit a default folder" do 
    default_category = @account.solution_categories.find_by_is_default(true)
    get :edit, :id => default_category.folders.first.id, :category_id => default_category.id
    session["flash"][:notice].should eql I18n.t(:'folder_edit_not_allowed')
  end  

  it "should delete a solution categories folder" do
    delete :destroy, :id => @test_folder.id, :category_id => @test_category.id
    @account.folders.find_by_name("#{@test_folder.name}").should be_nil
    response.should redirect_to(solution_category_path(@test_category))    
  end

  # Folder Bulk Actions starts from here
  describe "Folder Bulk Actions"  do

    before(:all) do
      @test_category2 = create_category( {:name => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", :is_default => false} )
      @test_folder3 = create_folder( {:name => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", :visibility => 1, :category_id => @test_category.id } )
      @test_folder4 = create_folder( {:name => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", :visibility => 1, :category_id => @test_category.id } )
      @folder_ids = [@test_folder3.id, @test_folder4.id]
    end

    # Start : Visible to
    describe "Visible to action"  do

      it "should change selected folders visibility to logged in users" do
        put :visible_to, :folderIds => @folder_ids, :visibility => Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:logged_users]
        [@test_folder3, @test_folder4].each do |folder|
          folder.reload
          folder.visibility.should be_eql(Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        end
      end

      it "should change all selected folders visibility to anyone" do
        put :visible_to, :folderIds => @folder_ids, :visibility => Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        [@test_folder3, @test_folder4].each do |folder|
          folder.reload
          folder.visibility.should be_eql(Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone])
        end
      end


      it "should change all selected folders visibility to agents" do
        put :visible_to, :folderIds => @folder_ids, :visibility => Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:agents]
        [@test_folder3, @test_folder4].each do |folder|
          folder.reload
          folder.visibility.should be_eql(Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:agents])
        end
      end

      describe "Adding Company visibility" do

        before(:all) do
          @company1 = Company.new(:name => Faker::Name.name)
          @company1.account_id = @test_folder.account_id
          @company1.save
          @company2 = Company.new(:name => "#{Faker::Name.name} - 2")
          @company2.account_id = @test_folder.account_id
          @company2.save
        end

        it "should change visibility: replace existing companies" do
          put :visible_to, :folderIds => @folder_ids, :visibility => Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users], :companies => [@company1.id, @company2.id], :addToExisting => 0
          [@test_folder3, @test_folder4].each do |folder|
            folder.reload
            folder.visibility.should be_eql(Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users])
            folder.customer_ids.should include(@company2.id, @company1.id)
          end

          put :visible_to, :folderIds => @folder_ids, :visibility => Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users], :companies => [@company1.id], :addToExisting => 0
          [@test_folder3, @test_folder4].each do |folder|
            folder.reload
            folder.visibility.should be_eql(Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users])
            folder.customer_ids.should include(@company1.id)
          end
        end

        it "should change visibility: add to existing companies" do
          put :visible_to, :folderIds => @folder_ids, :visibility => Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users], :companies => [@company2.id], :addToExisting => 1
          [@test_folder3, @test_folder4].each do |folder|
            folder.reload
            folder.visibility.should be_eql(Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users])
            folder.customer_ids.should include(@company2.id, @company1.id)
          end
        end

      end

    end
    # End : Visible to

    # Start : Move to Action
    describe "Move to action" do

      it "should move selected folders to another category" do
        request.env["HTTP_ACCEPT"] = "application/javascript"
        put :move_to, :items => @folder_ids, :parent_id => @test_category2.id
        [@test_folder3, @test_folder4].each do |folder|
          folder.reload
          folder.category_id.should be_eql(@test_category2.id)
        end
      end

      it "should render move_to.rjs" do
        xhr :put, :move_to, :items => @folder_ids, :parent_id => @test_category2.id
        response.body.should =~ /App.Solutions.Folder.removeElementsAfterMoveTo\(\)/
      end

      it "should reverse the changes done by move_to" do
        request.env["HTTP_ACCEPT"] = "application/javascript"
        put :move_back, :items => @folder_ids, :parent_id => @test_category.id
        [@test_folder3, @test_folder4].each do |folder|
          folder.reload
          folder.category_id.should be_eql(@test_category.id)
        end
      end

      it "should render move_back" do
        xhr :put, :move_back, :items => @folder_ids, :parent_id => @test_category.id
        response.should render_template('solution/folders/move_back')
      end

    end
    # End : Move to action

  end
  # END : Folder Bulk Actions

  describe "Solution Folder meta" do
    before(:all) do
      time = Time.now.to_i
      @test_folder_for_meta = create_folder( {:name => "#{time} test_folder_for_meta #{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", :visibility => 1,
     :category_id => @test_category.id } )
      @test_folder_for_meta.build_meta.save if @test_folder_for_meta.reload.solution_folder_meta.blank?
    end

    it "should create a new meta solution folder on solution folder create" do
      now = (Time.now.to_f*1000).to_i
      name = Faker::Name.name
      company = create_company
      post :create, {:solution_folder => {:name => "#{name}", :description => "#{Faker::Lorem.sentence(3)}", :visibility => 4},
          :category_id => @test_category.id, :customers => company.id }
      folder = @account.folders.find_by_name(name)
      folder.should be_an_instance_of(Solution::Folder) 
      check_meta_integrity(folder)
      customer_folder = @account.solution_customer_folders.find_by_folder_id(folder.id)
      customer_folder.should be_an_instance_of(Solution::CustomerFolder)
      customer_folder.folder_id.should be_eql(customer_folder.folder_meta_id)
    end

    it "should edit a solution folder meta on solution folder edit" do
      name = Faker::Name.name
      put :update, :id => @test_folder_for_meta.id, 
        :solution_folder => { :name => "#{name}",
                                :description => "#{Faker::Lorem.sentence(3)}",
                                :is_default => true,
                                :visibility => 2
                              },
        :category_id => @test_category.id
      check_meta_integrity(@test_folder_for_meta)
      response.should redirect_to(solution_folder_path(@test_folder_for_meta.id))
    end

    it "should destroy meta on folder destroy" do
      test_destroy_folder = create_folder( {:name => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", :visibility => 1,
     :category_id => @test_category.id } )
      test_destroy_folder.build_meta.save if test_destroy_folder.reload.solution_folder_meta.blank?
      delete :destroy, :id => test_destroy_folder.id, :category_id => @test_category.id
      @account.solution_folders.find_by_id(test_destroy_folder.id).should be_nil
      @account.solution_folder_meta.find_by_id(test_destroy_folder.id).should be_nil
    end

    it "should redirect to drafts page for default folder" do
      @test_folder_for_meta.update_attributes(:is_default => true)
      get :show, :id => @test_folder_for_meta.id, :category_id => @test_category.id
      response.should redirect_to(solution_my_drafts_path('all'))
    end
    
  end

  describe "Reorder folder meta" do
    it "should reorder folders and position changes must reflect in meta both on create and reorder" do
      category = create_category( {:name => "new category #{Faker::Name.name}", :description => "#{Faker::Lorem.sentence(3)}", :is_default => false} )   
      position_arr = (1..4).to_a.shuffle
      reorder_hash = {}
      for i in 0..3
        folder = create_folder( {:name => "new folder #{Faker::Name.name}", :description => "#{Faker::Lorem.sentence(3)}", :visibility => 1,
                    :category_id => category.id } )
        reorder_hash[folder.id] = position_arr[i] 
        folder.reload.solution_folder_meta.position.should be_eql(folder.position)
        folder.reload.solution_folder_meta.position.should be_eql(folder.read_attribute(:position))
      end
      put :reorder, :category_id => category.id, :reorderlist => reorder_hash.to_json
      category.folders.each do |current_folder|
        current_folder.position.should be_eql(reorder_hash[current_folder.id])
        current_folder.read_attribute(:position).should be_eql(reorder_hash[current_folder.id])
        current_folder.solution_folder_meta.position.should be_eql(reorder_hash[current_folder.id])
      end    
    end  

    it "should create meta on reorder of folders if meta is not present and position must be preserved on destroy" do
      category = create_category( {:name => "new category #{Faker::Name.name}", :description => "#{Faker::Lorem.sentence(3)}", :is_default => false} )   
      for i in 0..3
        folder = create_folder( {:name => "new folder #{Faker::Name.name}", :description => "#{Faker::Lorem.sentence(3)}", :visibility => 1,
                    :category_id => category.id } )
      end
      check_position(category, "folders")
      category.folders.first.destroy
      check_position(category, "folders")
    end
  end
end
