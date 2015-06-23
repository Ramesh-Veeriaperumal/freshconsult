module SolutionsHelper

  def create_category(params = {})
    test_category = FactoryGirl.build(:solution_categories, :name => params[:name] || Faker::Name.name,
              :description => params[:description], :is_default => params[:is_default], 
              :portal_ids => params[:portal_ids] || [] )
    test_category.account_id = @account.id
    test_category.save(validate: false)
    test_category
  end

  def create_folder(params = {})
    test_folder = FactoryGirl.build(:solution_folders, :name => params[:name] || Faker::Name.name,
              :description => params[:description], :visibility => params[:visibility], :category_id => params[:category_id])
    test_folder.account_id = @account.id
    test_folder.save(validate: false)
    test_folder
  end

  def create_article(params = {})
    test_article = FactoryGirl.build(:solution_articles, :title => params[:title], :description => params[:description],
      :folder_id => params[:folder_id], :status => params[:status], :art_type => params[:art_type])
    test_article.account_id = @account.id
    if params[:attachments]
      test_article.attachments.build(:content => params[:attachments][:resource], 
                                    :description => params[:attachments][:description], 
                                    :account_id => test_article.account_id)
    end
    test_article.user_id = params[:user_id] || @agent.id
    test_article.save(validate: false)
    test_article
  end

  def quick_create_artilce
    create_article(:folder_id => create_folder(:category_id => create_category.id).id)
  end

  def solutions_incremented? article_size
    @account.reload
    @account.solution_articles.size.should eql article_size+1
  end

  def show_page_rendered_properly?(test_article)
    get :show, :id => test_article.id, :category_id => test_article.folder.category_id, :folder_id => test_article.folder_id
    response.body.should =~ /#{test_article.title}/
    response.body.should =~ /#{test_article.description}/
    response.should render_template("solution/articles/show")
  end

  def check_article_body_integrity(article_obj, art_description, art_description_text)
    article_body = article_obj.original_article_body
    article_obj.should be_an_instance_of(Solution::Article)
    article_body.should be_an_instance_of(Solution::ArticleBody)
    
    article_obj.description.should be_eql(art_description)
    article_obj[:description].should be_eql(art_description)

    article_obj.desc_un_html.strip.should be_eql(art_description_text)
    article_obj[:desc_un_html].strip.should be_eql(art_description_text)

    article_body.description.should be_eql(art_description)
    article_body[:description].should be_eql(art_description)

    article_body.desc_un_html.strip.should be_eql(art_description_text)
    article_body[:desc_un_html].strip.should be_eql(art_description_text)
  end

  def create_portal(params = {})
    test_portal = FactoryGirl.build(:portal, 
                      :name=> params[:portal_name] || Faker::Name.name, 
                      :portal_url => params[:portal_url] || "", 
                      :language=>"en",
                      :forum_category_ids => (params[:forum_category_ids] || [""]),
                      :solution_category_ids => (params[:solution_category_ids] || [""]),
                      :account_id => @account.id,
                      :preferences=> { 
                        :logo_link=>"", 
                        :contact_info=>"", 
                        :header_color=>"#252525",
                        :tab_color=>"#006063", 
                        :bg_color=>"#efefef" 
                      })
    test_portal.save(validate: false)
    test_portal
  end

  def solution_test_setup
    @categories = []
    @portals = []

    0..5.times do 
      @portals << create_portal
    end

    for i in (1..5) do 
      cat = create_category( { :name => "#{Faker::Lorem.sentence(3)}",
                                        :description => "#{Faker::Lorem.sentence(3)}", 
                                        :is_default => false,
                                        :portal_ids => rand_portal_ids
                              })
      @categories << cat
      for i in (1..5) do 
        folder = create_folder( {:name => "#{Faker::Lorem.sentence(3)}", 
                                      :description => "#{Faker::Lorem.sentence(3)}",  
                                      :visibility => 1,
                                      :category_id => cat.id } )
        for i in (1..5) do 
          create_article( { :title => "#{Faker::Lorem.sentence(3)}", 
                            :description => "#{Faker::Lorem.sentence(3)}", :folder_id => folder.id,
                            :user_id => @agent.id, :status => "2", :art_type => "1" } )
        end
      end
    end
  end

  def rand_portal_ids
    ((rand(2..5)).times.collect do
      (@portals || []).map(&:id).sample
    end).uniq
  end

  def solution_cache_test_setup
    ActionController::Base.perform_caching = true
    @current_account = Account.current
    @current_portal  = Portal.first.make_current
    @cache_key = MemcacheKeys::ALL_SOLUTION_CATEGORIES % { :account_id => @current_account.id }
    solution_test_setup
  end

  def check_cache_invalidation
    $memcache.get(@cache_key).should be_nil
  end
end