require 'spec_helper'

describe Solution::FoldersController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @user = create_dummy_customer
    @test_category_meta = create_category
    @test_folder_meta = create_folder( {:category_id => @test_category_meta.id } )
    @test_folder_meta2 = create_folder( {:category_id => @test_category_meta.id } )
    @companies_array = []
    251.times do
      company = create_company
      @companies_array << company.id
    end
  end

  before(:each) do
    login_admin
  end

  it "should redirect to category show if folder index is hit" do 
    get :index, :category_id => @test_category_meta.id
    response.should redirect_to(solution_category_path(@test_category_meta.id))
  end

  it "should render a show page of a folder" do
    get :show, :id => @test_folder_meta.id
    response.body.should =~ /#{@test_folder_meta.primary_folder.name}/
    response.should render_template("solution/folders/show")
  end

  it "should redirect user with no privilege to login" do
    session = UserSession.find
    session.destroy
    log_in(@user)
    get :show, :id => @test_folder_meta.id
    flash[:notice] =~ I18n.t(:'flash.general.need_login')  
    UserSession.find.destroy
  end

  it "should redirect to support folder show if user is logged out" do 
    session = UserSession.find
    session.destroy
    get :show, :id => @test_folder_meta.id
    response.should redirect_to(support_solutions_folder_path(@test_folder_meta))
  end

  it "should reorder folders" do
    category_meta = create_category
    position_arr = (1..4).to_a.shuffle
    reorder_hash = {}
    for i in 0..3
      folder_meta = create_folder({:category_id => category_meta.id })
      reorder_hash[folder_meta.id] = position_arr[i] 
    end
    put :reorder, :category_id => category_meta.id, :reorderlist => reorder_hash.to_json
    category_meta.solution_folder_meta.each do |current_folder|
      current_folder.position.should be_eql(reorder_hash[current_folder.id])
    end    
  end 
  
  it "should render edit if folder update fails" do 
    put :update, :id => @test_folder_meta.id,
      :solution_folder_meta => {
        :id => @test_folder_meta.id,
        :primary_folder => {
          :name => nil,
          :description => "#{Faker::Lorem.sentence(3)}"
        }
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
    get :show, :id => @test_folder_meta.id
    response.status.should eql 302
    session["flash"][:notice].should eql I18n.t(:'flash.general.access_denied')
    UserSession.find.destroy
  end

  it "should render a new folder form" do 
    get :new, :category_id => @test_category_meta.id
    response.body.should =~ /Add Folder/
    response.should render_template("solution/folders/new")    
  end  

  it "should create a new solution category folder" do
    name = Faker::Name.name
    post :create, :solution_folder_meta => {
      :visibility => 1,
      :solution_category_meta_id => @test_category_meta.id,
      :primary_folder => {
        :name => "#{name}",
        :description => "#{Faker::Lorem.sentence(3)}"
      }
    }
    response.status.should eql 302
    @account.folders.find_by_name(name).should be_an_instance_of(Solution::Folder)    
  end

  it "should redirect to new page if folder create fails" do 
    post :create, :solution_folder_meta => {
      :visibility => 1,
      :solution_category_meta_id => @test_category_meta.id,
      :primary_folder => {
        :description => "#{Faker::Lorem.sentence(3)}"
      }
    }
    response.body.should =~ /Add Folder/
    response.should render_template("solution/folders/new")    
  end

  it "should edit a solution folder" do# failing in master
    get :edit, :id => @test_folder_meta.id
    response.body.should =~ /Edit Folder/
    name = Faker::Name.name
    put :update, :id => @test_folder_meta.id,
    :solution_folder_meta => {
      :id => @test_folder_meta.id,
      :primary_folder => {
        :name => name,
        :description => "#{Faker::Lorem.sentence(3)}"
      }
    }
    @account.folders.find_by_name("#{name}").should be_an_instance_of(Solution::Folder)
    response.should redirect_to(solution_folder_path(@test_folder_meta.id))
  end

  it "should not edit a default folder" do 
    default_category_meta = @account.solution_category_meta.find_by_is_default(true)
    get :edit, :id => default_category_meta.solution_folder_meta.first.id
    session["flash"][:notice].should eql I18n.t(:'folder_edit_not_allowed')
  end  

  it "should show error message if folder update fails due to exceeding companies limit" do
    put :update, :id => @test_folder_meta.id, 
      :solution_folder_meta => { 
        :id => @test_folder_meta.id,
        :visibility => Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users]
      },
      :customers => @companies_array.join(',')
    response.body.should include(I18n.t("solution.folders.visibility.companies_limit_exceeded"))
  end

  it "should delete a solution folder" do
    test_folder_meta = create_folder( {:category_id => @test_category_meta.id } )
    name = test_folder_meta.primary_folder.name
    delete :destroy, :id => test_folder_meta.id
    @account.folders.find_by_name(name).should be_nil
    response.should redirect_to(solution_category_path(@test_category_meta)) 
  end

  # Folder Bulk Actions starts from here
  describe "Folder Bulk Actions"  do

    before(:all) do
      @test_category_meta2 = create_category
      @test_folder_meta3 = create_folder( {:category_id => @test_category_meta.id } )
      @test_folder_meta4 = create_folder( {:category_id => @test_category_meta.id } )
      @test_folder_meta5 = create_folder( {:category_id => @test_category_meta.id } )
      @test_folder_meta6 = create_folder( {:category_id => @test_category_meta.id } )
      @folder_ids = [@test_folder_meta3.id, @test_folder_meta4.id]
      @folder_ids_1 = [@test_folder_meta5.id, @test_folder_meta6.id]
    end

    # Start : Visible to
    describe "Visible to action"  do

      it "should change selected folders visibility to logged in users" do
        put :visible_to, :folderIds => @folder_ids, :visibility => Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:logged_users]
        [@test_folder_meta3, @test_folder_meta4].each do |folder|
          folder.reload
          folder.visibility.should be_eql(Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        end
      end

      it "should change all selected folders visibility to anyone" do
        put :visible_to, :folderIds => @folder_ids, :visibility => Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        [@test_folder_meta3, @test_folder_meta4].each do |folder|
          folder.reload
          folder.visibility.should be_eql(Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone])
        end
      end


      it "should change all selected folders visibility to agents" do
        put :visible_to, :folderIds => @folder_ids, :visibility => Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:agents]
        [@test_folder_meta3, @test_folder_meta4].each do |folder|
          folder.reload
          folder.visibility.should be_eql(Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:agents])
        end
      end

      describe "Adding Company visibility" do

        before(:all) do
          @company1 = Company.new(:name => Faker::Name.name)
          @company1.account_id = @test_folder_meta3.account_id
          @company1.save
          @company2 = Company.new(:name => "#{Faker::Name.name} - 2")
          @company2.account_id = @test_folder_meta3.account_id
          @company2.save
        end

        it "should change visibility: replace existing companies" do
          put :visible_to, :folderIds => @folder_ids, :visibility => Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users], :companies => [@company1.id, @company2.id], :addToExisting => 0
          [@test_folder_meta3, @test_folder_meta4].each do |folder|
            folder.reload
            folder.visibility.should be_eql(Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users])
            folder.customer_ids.should include(@company2.id, @company1.id)
          end

          put :visible_to, :folderIds => @folder_ids, :visibility => Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users], :companies => [@company1.id], :addToExisting => 0
          [@test_folder_meta3, @test_folder_meta4].each do |folder|
            folder.reload
            folder.visibility.should be_eql(Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users])
            folder.customer_ids.should include(@company1.id)
          end
        end

        it "should change visibility: add to existing companies" do
          put :visible_to, :folderIds => @folder_ids, :visibility => Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users], :companies => [@company2.id], :addToExisting => 1
          [@test_folder_meta3, @test_folder_meta4].each do |folder|
            folder.reload
            folder.visibility.should be_eql(Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users])
            folder.customer_ids.should include(@company2.id, @company1.id)
          end
        end

        it "should not change the visibility when company limit exceeds: replace existing companies" do
          put :visible_to, :folderIds => @folder_ids_1, :visibility => Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone]
          put :visible_to, :folderIds => @folder_ids_1, :visibility => Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users], :companies => @companies_array, :addToExisting => 0
          expect(flash[:error]).to be_present
          expect(flash[:notice]).to_not be_present
          [@test_folder_meta5, @test_folder_meta6].each do |folder|
            folder.reload
            folder.visibility.should_not be_eql(Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users])
            folder.customer_ids.should eql([])
          end
        end

        it "should not change the visibility for folders where company limit exceeds: add to existing companies" do
          put :update, :id => @test_folder_meta6.id, :customers => [@company1.id, @company2.id].join(','), 
          :solution_folder_meta => {
            :id => @test_folder_meta6.id,
            :visibility => Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users]
          }
          put :visible_to, :folderIds => @folder_ids_1, :visibility => Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users], :companies => @companies_array.first(250), :addToExisting => 1
          expect(flash[:error]).to be_present
          expect(flash[:notice]).to be_present
          @test_folder_meta5.reload
          @test_folder_meta5.visibility.should eql(Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users])
          @test_folder_meta5.customer_ids.sort.should eql(@companies_array.first(250))
          @test_folder_meta6.reload
          @test_folder_meta6.customer_ids.should eql([@company1.id, @company2.id])
        end

      end

    end
    # End : Visible to

    # Start : Move to Action
    describe "Move to action" do

      it "should move selected folders to another category" do
        request.env["HTTP_ACCEPT"] = "application/javascript"
        put :move_to, :items => @folder_ids, :parent_id => @test_category_meta2.id
        [@test_folder_meta3, @test_folder_meta4].each do |folder|
          folder.reload
          folder.solution_category_meta_id.should be_eql(@test_category_meta2.id)
        end
      end

      it "should reload the page if category id is not valid" do
        request.env["HTTP_ACCEPT"] = "application/javascript"
        put :move_to, :items => @folder_ids, :parent_id => "test"
        response.body.should =~ /location.reload()/
        expect(flash[:notice]).to be_present
      end

      it "should render move_to.rjs" do
        xhr :put, :move_to, :items => @folder_ids, :parent_id => @test_category_meta2.id
        response.body.should =~ /App.Solutions.Folder.removeElementsAfterMoveTo/
      end

      it "should reverse the changes done by move_to" do
        request.env["HTTP_ACCEPT"] = "application/javascript"
        put :move_back, :items => @folder_ids, :parent_id => @test_category_meta.id
        [@test_folder_meta3, @test_folder_meta4].each do |folder|
          folder.reload
          folder.solution_category_meta_id.should be_eql(@test_category_meta.id)
        end
      end

      it "should render move_back" do
        xhr :put, :move_back, :items => @folder_ids, :parent_id => @test_category_meta.id
        response.should render_template('solution/folders/move_back')
      end

    end
    # End : Move to action

  end
  # END : Folder Bulk Actions

  describe "Reorder folder meta" do
    it "should reorder folders and position changes must reflect in meta both on create and reorder" do
      category_meta = create_category
      
      position_arr = (1..4).to_a.shuffle
      reorder_hash = {}
      for i in 0..3
        folder_meta = create_folder({:category_id => category_meta.id })
        reorder_hash[folder_meta.id] = position_arr[i]
      end
      put :reorder, :category_id => category_meta.id, :reorderlist => reorder_hash.to_json
      category_meta.solution_folder_meta.each do |current_folder|
        current_folder.position.should be_eql(reorder_hash[current_folder.id])
      end    
    end

  end
end
