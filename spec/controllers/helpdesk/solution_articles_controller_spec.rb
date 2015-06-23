require 'spec_helper'

describe Solution::ArticlesController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @user = create_dummy_customer
    @user_1 = create_dummy_customer
    @now = (Time.now.to_f*1000).to_i
    @test_category = create_category( {:name => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", :is_default => false} )
    @test_folder = create_folder( {:name => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", :visibility => 1, :category_id => @test_category.id } )
    @test_article = create_article( {:title => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", :folder_id => @test_folder.id, :user_id => @agent.id, :status => "2", :art_type => "1" } )
    @test_article2 = create_article( {:title => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", :folder_id => @test_folder.id, :user_id => @agent.id, :status => "2", :art_type => "1" } )
  end

  before(:each) do
    log_in(@agent)
    stub_s3_writes
  end

  it "should redirect to folder show if article index is hit" do 
    get :index, :category_id => @test_category.id, :folder_id => @test_folder.id
    response.should redirect_to(solution_category_folder_url(@test_category.id,@test_folder.id))
  end

  it "should render a show page of an article" do
    file = fixture_file_upload('/files/attachment.txt', 'text/plain', :binary)
    article_with_attachments = create_article( {:title => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", :folder_id => @test_folder.id,
      :user_id => @agent.id, :status => "2", :art_type => "1",
      :attachments => { :resource => file, :description => Faker::Lorem.characters(10)}
    } )
    get :show, :id => article_with_attachments.id, :category_id => @test_category.id, :folder_id => @test_folder.id
    response.body.should =~ /#{article_with_attachments.title}/
    response.should render_template("solution/articles/show")    
  end

  it "should redirect user with no privilege to login" do 
    session = UserSession.find
    session.destroy
    log_in(@user)
    get :show, :id => @test_article.id, :category_id => @test_category.id, :folder_id => @test_folder.id
    flash[:notice] =~ I18n.t(:'flash.general.need_login')  
    UserSession.find.destroy
  end

  it "should not show article to restricted agent" do
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
    get :show, :id => @test_article.id, :category_id => @test_category.id, :folder_id => @test_folder.id
    response.status.should eql 302
    session["flash"][:notice].should eql I18n.t(:'flash.general.access_denied')
    UserSession.find.destroy    
  end

  it "should reorder articles" do
    folder = create_folder( {:name => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", :visibility => 1,
      :category_id => @test_category.id } )
    position_arr = (1..4).to_a.shuffle
    reorder_hash = {}
    for i in 0..3
      article = create_article( {:title => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", :folder_id => @test_folder.id,
      :user_id => @agent.id, :status => "2", :art_type => "1" } )
      reorder_hash[article.id] = position_arr[i] 
    end
    put :reorder, :category_id => @test_category.id, :folder_id => folder.id, :reorderlist => reorder_hash.to_json
    folder.articles.each do |current_article|
      current_article.position.should be_eql(reorder_hash[current_article.id])
    end    
  end  

  it "should render a new article form" do 
    get :new, :category_id => @test_category.id, :folder_id => @test_folder.id
    response.should render_template("solution/articles/new")    
  end

  it "should create a new solution article" do
    now = (Time.now.to_f*1000).to_i
    name = Faker::Name.name
    post :create, { :solution_article => {:title => "#{name}",
      :description => "#{Faker::Lorem.sentence(3)}" ,:folder_id => @test_folder.id, :status => 2, :art_type => 1},
      :tags => {:name => "new"}
    }
    @account.solution_articles.find_by_title(name).should be_an_instance_of(Solution::Article)            
  end

  it "should create a new solution article and the content must be saved in article bodies table" do
    name = "#{Faker::Name.name} #{(Time.now.to_f*1000).to_i.to_s}"
    art_description_text = Faker::Lorem.sentence(3)
    art_description = "<p>#{art_description_text}</p>"
    post :create, { :solution_article => {
        :title => name,
        :description => art_description ,
        :folder_id => @test_folder.id, :status => 2, :art_type => 1
      }
    }
    article_obj = @account.solution_articles.find_by_title(name)
    check_article_body_integrity(article_obj, art_description, art_description_text)
  end

  it "should redirect to new page if article create fails" do 
    post :create, :solution_article => {:description => "#{Faker::Lorem.sentence(3)}", :folder_id => @test_folder.id, :status => 2, :art_type => 1},
                                        :tags => {:name => ""}
    response.should render_template("solution/articles/new")    
  end

  it "should edit a solution article" do
    get :edit, :id => @test_article.id, :folder_id => @test_folder.id, :category_id => @test_category.id
    response.body.should =~ /solution\/articles\/(.+)#edit/ 
    name = Faker::Name.name   
    put :update, { :id => @test_article.id, 
                   :solution_article => {:title => "#{name}",
                                          :description => "#{Faker::Lorem.sentence(3)}",
                                          :folder_id => "#{@test_folder.id}",
                                          :status => "2",
                                          :art_type => "1"
                                          },
                    :tags => {:name => ""},
                    :category_id => @test_category.id,
                    :folder_id => @test_folder.id
                  }
    @test_article.reload                  
    @account.solution_articles.find_by_title(name).should be_an_instance_of(Solution::Article)    
  end

  it "should update a solution article and any changes made in the content should reflect in article_bodies table" do
    art_description_text = Faker::Lorem.sentence(3)
    art_description = "<p>#{art_description_text}</p>"
    put :update, { :id => @test_article.id, 
                   :solution_article => {:title => @test_article.title,
                                          :description => art_description,
                                          :folder_id => @test_folder.id,
                                          :status => "2",
                                          :art_type => "1"
                                          },
                    :category_id => @test_category.id,
                    :folder_id => @test_folder.id
                  }
    @test_article.reload                  
    check_article_body_integrity(@test_article, art_description, art_description_text)
  end

  it "should add attahchment to article" do 
    Resque.inline = true
    put :update, { :id => @test_article.id, 
                   :solution_article => { :attachments => [{"resource" => fixture_file_upload('files/image.gif', 'image/gif')}] },
                    :tags => {:name => ""},
                    :category_id => @test_category.id, 
                    :folder_id => @test_folder.id 
                  }
    Resque.inline = false
    @test_article.reload
    @test_article.attachments.size.should eql 1                  
  end

  it "should redirect to support article page if user is logged out" do     
    session = UserSession.find
    session.destroy
    get :show, :id => @test_article.id, :category_id => @test_category.id, :folder_id => @test_folder.id, :format => nil 
    response.should redirect_to(support_solutions_article_path(@test_article.id))    
  end

  #test below failing, will pass when dynamic solution feature is implemented.

  # it "should redirect back if article update fails" do 
  #   put :update, { :id => @test_article.id, 
  #                  :solution_article => {:title => nil,
  #                                         :description => "Update solution article #{@now}",
  #                                         :folder_id => "#{@test_folder.id}", 
  #                                         :status => "2",
  #                                         :art_type => "1"
  #                                         },
  #                   :tags => {:name => ""},
  #                   :category_id => @test_category.id, 
  #                   :folder_id => @test_folder.id 
  #                 }            
  #   response.body.should =~ /Edit Solution/    
  #   response.should render_template("solution/articles/edit")    

  # end  

  it "should delete a solution article" do
    title = @test_article.title
    delete :destroy, :id => @test_article.id, :category_id => @test_category.id, :folder_id => @test_folder.id
    @account.solution_articles.find_by_title(title).should be_nil
    response.should redirect_to(solution_category_folder_url(@test_category.id,@test_folder.id ))
  end

  describe "Modified at column" do
    before(:each) do
      now = (Time.now.to_f*1000).to_i
      name = Faker::Name.name
      post :create, { :solution_article => {:title => name,
        :description => Faker::Lorem.sentence(3) ,:folder_id => @test_folder.id, :status => 2, :art_type => 1},
        :tags => {:name => "new"}
      }
      @article = @account.solution_articles.find_by_title(name)
    end

    it "should be same as updated at while creating a new article" do
      @article.updated_at.should eql @article.modified_at
    end

    it "should be modified when title changes" do
      sleep(2)
      put :update, { :id => @article.id, 
                    :solution_article => { :title => "Title Changed" },
                    :tags => {:name => ""},
                    :category_id => @test_category.id, 
                    :folder_id => @test_folder.id 
                  }
      @article.reload
      @article.updated_at.should eql @article.modified_at
    end

    it "should be modified when description changes" do
      sleep(2)
      put :update, { :id => @article.id, 
                    :solution_article => { :description => Faker::Lorem.sentence(2) },
                    :tags => {:name => ""},
                    :category_id => @test_category.id, 
                    :folder_id => @test_folder.id 
                  }
      @article.reload
      @article.updated_at.should eql @article.modified_at
    end

    it "should not change when other column values changes" do
      sleep(2)
      put :update, { :id => @article.id, 
                    :solution_article => { :status => 1 },
                    :tags => {:name => ""},
                    :category_id => @test_category.id, 
                    :folder_id => @test_folder.id
                  }
      @article.reload
      @article.updated_at.should_not eql @article.modified_at
    end

    it "should reset thumbs_up and thumbs_down & destroy the votes for that article when reset ratings is done" do
      @test_article = create_article( {:title => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", :folder_id => @test_folder.id,
                                       :user_id => @agent.id, :status => "2", :art_type => "1" } )
      @test_article.reload
      @test_article.thumbs_up = rand(5..10)
      @test_article.thumbs_down = rand(5..10)
      @test_article.votes.build(:vote => 1, :user_id => @user.id)
      @test_article.votes.build(:vote => 0, :user_id => @user_1.id)
      @test_article.reload.save
      put :reset_ratings, :id => @test_article.id, :category_id => @test_category.id, :folder_id => @test_folder.id
      @test_article.reload
      @test_article.thumbs_up.should eql 0
      @test_article.thumbs_down.should eql 0
      @test_article.votes.should eql []
    end
  end

  # Start : Bulk Actions
  describe "Bulk Actions (Move to and Change Author)" do
    before(:all) do
      @test_folder2 = create_folder( {:name => "#{Faker::Lorem.sentence(2)}", :description => "#{Faker::Lorem.sentence(3)}", :visibility => 1, :category_id => @test_category.id } )
      @test_article3 = create_article( {:title => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", :folder_id => @test_folder.id, :user_id => @agent.id, :status => "2", :art_type => "1" } )
      @test_article4 = create_article( {:title => "#{Faker::Lorem.sentence(5)}", :description => "#{Faker::Lorem.sentence(5)}", :folder_id => @test_folder.id, :user_id => @agent.id, :status => "2", :art_type => "1" } )
      @article_ids = [@test_article3.id, @test_article4]
    end

    describe "Move to" do

      it "should move selected articles to another folder" do
        put :move_to, :items => @article_ids, :parent_id => @test_folder2.id
        [@test_article3, @test_article4].each do |article|
          article.reload
          article.folder_id.should be_eql(@test_folder2.id)
        end
      end

      it "should render move_to.rjs" do
        xhr :put, :move_to, :items => @article_ids, :parent_id => @test_folder2.id
        response.body.should =~ /App.Solutions.Folder.removeElementsAfterMoveTo\(\)/
      end

      it "should reverse the changes done by move_to" do
        put :move_back, :items => @article_ids, :parent_id => @test_folder.id
        [@test_article3, @test_article4].each do |article|
          article.reload
          article.folder_id.should be_eql(@test_folder.id)
        end
      end

      it "should render move_back.rjs" do
        xhr :put, :move_back, :items => @article_ids, :parent_id => @test_folder.id
        response.should render_template('solution/articles/move_back')
      end

    end

    describe "Change Author" do
      before(:all) do
        @agent2 = add_test_agent
      end

      it "should chnage the authors of the articles" do
        #initially the author should be different
        [@test_article3, @test_article4].each do |article|
          article.user_id.should_not be_eql(@agent2.id)
        end

        put :change_author, :items => @article_ids, :parent_id => @agent2.id

        #the author should be changed
        [@test_article3, @test_article4].each do |article|
          article.reload
          article.user_id.should be_eql(@agent2.id)
        end
      end

      it "should not change author of articles unless admin" do
        @agent3 = add_test_agent
        @agent3.privileges = "4161535"
        @agent3.save
        
        log_in(@agent3)

        #initially the author should be different
        [@test_article3, @test_article4].each do |article|
          article.user_id.should_not be_eql(@agent3.id)
        end

        put :change_author, :items => @article_ids, :parent_id => @agent3.id

        #the author should be changed
        [@test_article3, @test_article4].each do |article|
          article.reload
          article.user_id.should_not be_eql(@agent3.id)
        end

      end

    end

  end
  # End : Bulk Actions

end
