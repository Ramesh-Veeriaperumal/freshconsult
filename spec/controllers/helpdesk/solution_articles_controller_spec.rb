require 'spec_helper'

describe Solution::ArticlesController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @user = create_dummy_customer
    @user_1 = create_dummy_customer
    @now = (Time.now.to_f*1000).to_i
    @test_category_meta = create_category
    @test_folder_meta = create_folder( {:category_id => @test_category_meta.id } )
    @test_article_meta = create_article({:folder_id => @test_folder_meta.id})
    @test_article = @test_article_meta.primary_article
    @test_article2_meta = create_article({:folder_id => @test_folder_meta.id})
    @test_article2 = @test_article2_meta.primary_article
  end

  before(:each) do
    log_in(@agent)
    stub_s3_writes
  end

  it "should redirect to folder show if article index is hit" do 
    get :index, :folder_id => @test_folder_meta.id
    response.should redirect_to(solution_folder_path(@test_folder_meta.id))
  end

  it "should render a show page of an article" do
    file = fixture_file_upload('/files/attachment.txt', 'text/plain', :binary)
    article_with_attachments = create_article({
      :folder_id => @test_folder_meta.id,
      :attachments => [{ :resource => file, :description => Faker::Lorem.characters(10)}]
    })
    get :show, :id => article_with_attachments.id
    response.body.should  include(article_with_attachments.primary_article.title)
    response.should render_template("solution/articles/show")
  end

  it "should redirect user with no privilege to login" do 
    session = UserSession.find
    session.destroy
    log_in(@user)
    get :show, :id => @test_article_meta.id
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
    get :show, :id => @test_article_meta.id
    response.status.should eql 302
    session["flash"][:notice].should eql I18n.t(:'flash.general.access_denied')
    UserSession.find.destroy    
  end

  it "should reorder articles" do
    folder_meta = create_folder({:category_id => @test_category_meta.id})
    position_arr = (1..4).to_a.shuffle
    reorder_hash = {}
    for i in 0..3
      article = create_article({:folder_id => folder_meta.id})
      reorder_hash[article.id] = position_arr[i] 
    end
    put :reorder, :folder_id => folder_meta.id, :reorderlist => reorder_hash.to_json
    folder_meta.solution_article_meta.each do |current_article|
      current_article.position.should be_eql(reorder_hash[current_article.id])
    end    
  end  

  it "should render a new article form" do 
    get :new, :folder_id => @test_folder_meta.id
    response.should render_template("solution/articles/new")    
  end

  it "should create a new solution article" do
    name = "#{Faker::Name.name} - #{(Time.now.to_f*1000).to_i}"
    post :create, 
    { :solution_article_meta => {
        :primary_article => {
          :title => name,
          :description => "#{Faker::Lorem.sentence(3)}",
          :tags => {:name => "new"},
          :status => 2
        },
        :art_type => 1,
        :folder_id => @test_folder_meta.id
      }
    }
    article = @account.solution_articles.find_by_title(name)
    article.should be_an_instance_of(Solution::Article)
    response.should redirect_to(solution_article_version_path(article.parent_id, article.language.code))
  end

  it "should create a new solution article and the content must be saved in article bodies table" do
    name = "#{Faker::Name.name} #{(Time.now.to_f*1000).to_i.to_s}"
    art_description_text = Faker::Lorem.sentence(3)
    art_description = "<p>#{art_description_text}</p>"
    post :create, 
    { :solution_article_meta => {
        :primary_article => {
          :title => name,
          :description => art_description,
          :tags => {:name => "new"},
          :status => 2
        },
        :art_type => 1,
        :folder_id => @test_folder_meta.id
      }
    }
    article_obj = @account.solution_articles.find_by_title(name)
    check_article_body_integrity(article_obj, art_description, art_description_text)
  end

  it "should redirect to new page if article create fails" do
    art_description_text = Faker::Lorem.sentence(3) 
    post :create, 
    :solution_article_meta => {
        :primary_article => {
          :description => art_description_text,
          :tags => {:name => "new"},
          :status => 2
        },
        :art_type => 1,
        :solution_folder_meta_id  => @test_folder_meta.id
      }
    response.should render_template("solution/articles/new")    
  end

  it "should edit a solution article" do
    name = "#{Faker::Name.name} #{(Time.now.to_f*1000).to_i.to_s}"
    art_description_text = Faker::Lorem.sentence(3)
    get :edit, :id => @test_article_meta.id
    response.should  redirect_to("/solution/articles/#{@test_article_meta.id}-#{@test_article_meta.primary_article.title[0..100].downcase.gsub(/[^a-z0-9]+/i, '-')}#edit")
    name = Faker::Name.name
    put :update, :id => @test_article_meta.id,  
      :solution_article_meta => {
        :id => @test_article_meta.id,
        :art_type => 1,
        :primary_article => {
          :title => name,
          :description => "#{Faker::Lorem.sentence(3)}",
          :status => 2,
          :tags => {:name => "coool man"}
        }
      }
    @test_article_meta.reload
    @account.solution_articles.find_by_title(name).should be_an_instance_of(Solution::Article)
  end

  it "should update a solution article and any changes made in the content should reflect in article_bodies table" do
    art_description_text = Faker::Lorem.sentence(3)
    art_description = "<p>#{art_description_text}</p>"
    put :update, :id => @test_article_meta.id,
      :solution_article_meta => {
        :id => @test_article_meta.id,
        :primary_article => {
          :description => art_description
        }
      }
    @test_article_meta.reload                  
    check_article_body_integrity(@test_article, art_description, art_description_text)
  end

  it "should add attachment to article" do 
    Resque.inline = true
    put :update, :id => @test_article_meta.id, 
      :solution_article_meta => {
        :id => @test_article_meta.id,
        :primary_article => {
          :attachments => [{"resource" => fixture_file_upload('files/image.gif', 'image/gif')}],
          :tags => {:name => "sample"}
        }
      }
    Resque.inline = false
    @test_article.reload
    @test_article.attachments.size.should eql 1                  
  end

  it "should redirect to support article page if user is logged out" do     
    session = UserSession.find
    session.destroy
    get :show, :id => @test_article_meta.id
    response.should redirect_to(support_solutions_article_path(@test_article_meta.id))    
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

  it "should delete a solution article and its versions" do
    test_article_meta = create_article({:folder_id => @test_folder_meta.id})
    test_article = test_article_meta.primary_article
    title = test_article.title
    delete :destroy, :id => test_article_meta.id
    expect(@account.solution_articles.find_by_title(title)).to be_nil
    expect(@account.solution_article_meta.find_by_id(test_article_meta.id)).to be_nil
    expect(response).to redirect_to(solution_folder_path(test_article_meta.solution_folder_meta_id))
  end

  describe "Modified at column" do
    before(:each) do
      name = "#{Faker::Name.name} #{(Time.now.to_f*1000).to_i.to_s}"
      art_description_text = Faker::Lorem.sentence(3)
      art_description = "<p>#{art_description_text}</p>"
      post :create, 
        :solution_article_meta => {
          :primary_article => {
            :title => name,
            :description => art_description,
            :tags => {:name => "new"},
            :status => 2
          },
          :art_type => 1,
          :solution_folder_meta_id => @test_folder_meta.id
        }
      @article = @account.solution_articles.find_by_title(name)
      @article_meta = @article.solution_article_meta
    end

    it "should be same as updated at while creating a new article" do
      @article.updated_at.should eql @article.modified_at
    end

    it "should be modified when title changes" do
      put :update, :id => @article.solution_article_meta.id,
        :solution_article_meta => {
          :id => @article.solution_article_meta.id,
          :primary_article => {
            :title => Faker::Name.name
          }
        }
      @article.reload
      @article.updated_at.should eql @article.modified_at
    end

    it "should be modified when article body changes" do
      put :update, :id => @article.solution_article_meta.id,
        :solution_article_meta => {
          :id => @article.solution_article_meta.id,
          :primary_article => {
            :description => Faker::Name.name
          }
        }
      @article.reload
      @article.article_body.updated_at.should eql @article.modified_at
    end

    it "should not change when other column values changes" do
      sleep(2)
      put :update, :id => @article.solution_article_meta.id, 
        :solution_article_meta => {
          :id => @article.solution_article_meta.id,
          :primary_article => {
            :status => 2,
            :tags => {:name => "sample test"}
          }
        }
      @article.reload
      @article.updated_at.should_not eql @article.modified_at
    end

    after(:each) do
      @article.solution_article_meta.destroy
    end
  end

  it "should reset thumbs_up and thumbs_down & destroy the votes for that article when reset ratings is done" do
    test_article_meta = create_article({:folder_id => @test_folder_meta.id, :status => 2})
    test_article = test_article_meta.primary_article
    
    test_article.thumbs_up = rand(5..10)
    test_article.thumbs_down = rand(5..10)
    test_article.votes.build(:vote => 1, :user_id => @user.id)
    test_article.votes.build(:vote => 0, :user_id => @user_1.id)
    test_article.save

    put :reset_ratings, :id => test_article_meta.id
    test_article.reload
    test_article.thumbs_up.should eql 0
    test_article.thumbs_down.should eql 0
    test_article.votes.should eql []
  end

  describe "Bulk Actions (Move to and Change Author)" do
    before(:all) do
      @test_folder_meta2 = create_folder( {:category_id => @test_category_meta.id } )
      @test_article_meta3 = create_article({:folder_id => @test_folder_meta.id})
      @test_article_meta4 = create_article({:folder_id => @test_folder_meta.id})
      @article_ids = [@test_article_meta3.id, @test_article_meta4.id]
    end

    describe "Move to" do

      it "should move selected articles to another folder" do
        request.env["HTTP_ACCEPT"] = "application/javascript"
        put :move_to, :items => @article_ids, :parent_id => @test_folder_meta2.id
        [@test_article_meta3, @test_article_meta4].each do |article|
          article.reload
          article.solution_folder_meta_id.should be_eql(@test_folder_meta2.id)
        end
      end

      it "should reload the page if folder id is not valid" do
        request.env["HTTP_ACCEPT"] = "application/javascript"
        put :move_to, :items => @article_ids, :parent_id => "test"
        response.body.should =~ /location.reload()/
        expect(flash[:notice]).to be_present
      end

      it "should render move_to.rjs" do
        xhr :put, :move_to, :items => @article_ids, :parent_id => @test_folder_meta2.id
        response.body.should =~ /App.Solutions.Folder.removeElementsAfterMoveTo/
      end

      it "should reverse the changes done by move_to" do
        request.env["HTTP_ACCEPT"] = "application/javascript"
        put :move_back, :items => @article_ids, :parent_id => @test_folder_meta.id
        [@test_article_meta3, @test_article_meta4].each do |article|
          article.reload
          article.solution_folder_meta_id.should be_eql(@test_folder_meta.id)
        end
      end

      it "should render move_back.rjs" do
        xhr :put, :move_back, :items => @article_ids, :parent_id => @test_folder_meta.id
        response.should render_template('solution/articles/move_back')
      end

    end

  end

  describe "Reorder article meta" do
    it "should reorder articles and position changes must reflect in meta both on create and reorder" do
      test_folder_meta = create_folder({:category_id => @test_category_meta.id })
      position_arr = (1..4).to_a.shuffle
      reorder_hash = {}
      for i in 0..3
        article_meta = create_article({:folder_id => test_folder_meta.id})
        reorder_hash[article_meta.id] = position_arr[i] 
        article_meta.position.should be_eql(article_meta.position)
      end
      put :reorder, :folder_id => test_folder_meta.id, :reorderlist => reorder_hash.to_json
      test_folder_meta.solution_article_meta.each do |article_meta|
        article_meta.position.should be_eql(reorder_hash[article_meta.id])
        article_meta.position.should be_eql(reorder_hash[article_meta.id])
      end    
    end  
  end 

  it "should check the language utility methods" do
    test_language_article = create_article({:folder_id => @test_folder_meta.id}).primary_article

    lang = Language.find_by_code("fr")
    old_language_id = test_language_article.language_id
    test_language_article.language_id = Language.find_by_code("fr").id
    test_language_article.save

    test_language_article.reload
    test_language_article.language_id.should be_eql(lang.id)
    test_language_article.language.name.should be_eql(lang.name)
    test_language_article.language.code.should be_eql(lang.code)
    test_language_article.language.should be_eql(lang)
    test_language_article.update_attribute(:language_id, old_language_id)
  end

  describe "Change Author[Prop Update]" do
    before(:each) do
      @test_article_meta3 = @test_article_meta = create_article({:folder_id => @test_folder_meta.id})
      @agent1  = add_test_agent
    end
    
    it "should not change author even if new author is agent but logged in is a user not agent" do
      log_in(@user)
      @test_article_meta3.primary_article.user_id.should_not be_eql(@agent1.id)
      put :update, :id => @test_article_meta3.id, :update_properties => 1,
      :solution_article_meta => {
        :id => @test_article_meta3.id,
        :art_type => 1,
        :primary_article => {
          :status => 2,
          :user_id => @agent1.id
        }
      }
      @test_article_meta3.reload
      @test_article_meta3.primary_article.user_id.should_not be_eql(@agent1.id)
    end

    it "should not change author even if admin but new author is not agent" do
      log_in(@agent)
      @test_article_meta3.primary_article.user_id.should_not be_eql(@user.id)
      put :update, :id => @test_article_meta3.id, :update_properties => 1,
      :solution_article_meta => {
        :id => @test_article_meta3.id,
        :primary_article => {
          :status => 2,
          :user_id => @user.id
        }
      }
      @test_article_meta3.reload
      @test_article_meta3.primary_article.user_id.should_not be_eql(@user.id)
    end
    
    it "should change author of the article if admin and new author is agent" do
      log_in(@agent)
      @test_article_meta3.primary_article.user_id.should_not be_eql(@agent1.id)
      put :update, :id => @test_article_meta3.id, :update_properties => 1,
      :solution_article_meta => {
        :id => @test_article_meta3.id,
        :primary_article => {
          :status => 2,
          :user_id => @agent1.id
        }
      }
      @test_article_meta3.reload
      @test_article_meta3.primary_article.user_id.should be_eql(@agent1.id)
    end
  end

  it "should return attributes from folder_meta table in to_indexed_json of article" do
    folder_meta = @test_folder_meta = create_folder( {:category_id => @test_category_meta.id } )
    create_customer_folders(folder_meta)
    folder_meta.reload
    test_language_article = @test_article_meta = create_article({:folder_id => folder_meta.id}).primary_article
    test_language_article.reload
    folder_meta = test_language_article.solution_folder_meta
    indexed_json = JSON.parse(test_language_article.to_indexed_json)
    indexed_json["solution/article"]["language_id"].should be_eql(test_language_article.language_id)
    indexed_json["solution/article"]["folder_id"].should be_eql(folder_meta.id)
    indexed_json["solution/article"]["folder"]["category_id"].should be_eql(folder_meta.solution_category_meta_id)
    indexed_json["solution/article"]["folder"]["visibility"].should be_eql(folder_meta.visibility)
    indexed_json["solution/article"]["folder"]["customer_folders"].each_with_index do |cf,i|
      cf["customer_id"].should be_eql(folder_meta.customer_folders[i].customer_id)
    end
  end
end
