module SolutionsHelper
  
  CREATE_METHODS = ["create_category", "create_folder", "create_article"]

  def create_category(params = {})
    c_params = create_solution_category_alone(solution_default_params(:category, :name, {
      :name => params[:name],
      :description => params[:description]
    }))
    c_params[:solution_category_meta][:is_default] = params[:is_default] if params[:is_default].present?
    c_params[:solution_category_meta][:portal_ids] = params[:portal_ids] if params[:portal_ids].present?
    category_meta = Solution::Builder.category(c_params)
    category_meta
  end

  def create_folder(params = {})
    f_params = create_solution_folder_alone(solution_default_params(:folder, :name, {
        :name => params[:name],
        :description => params[:description]
      }).merge({
        :category_id => params[:category_meta_id] || params[:category_id],
        :visibility => params[:visibility]
      }))
    f_params[:solution_folder_meta][:is_default] = params[:is_default] if params[:is_default].present?
    folder_meta = Solution::Builder.folder(f_params)
    folder_meta
  end

  def create_article(params = {})
    params = create_solution_article_alone(solution_default_params(:article, :title, {
      :title => params[:title],
      :description => params[:description]
      }).merge({
        :folder_id => params[:folder_meta_id] || params[:folder_id],
        :art_type => params[:art_type],
        :status => params[:status] || 2,
        :user_id => params[:user_id] || @agent.id,
        :attachments => params[:attachments]
      }))
    current_user_present = User.current.present?
    Account.current.users.find(params[:user_id] || @agent.id).make_current unless current_user_present
    article_meta = Solution::Builder.article(params.deep_symbolize_keys)
    User.reset_current_user unless current_user_present
    article_meta
  end
  
  CREATE_METHODS.each do |meth|
    define_method "#{meth}_with_language_reset" do |params = {}|
      return send("#{meth}_without_language_reset", params) unless Language.current?
      current_lang = Language.current
      Language.reset_current
      solution_obj = send("#{meth}_without_language_reset", params)
      current_lang.make_current
      solution_obj
    end
    
    alias_method_chain meth.to_sym, :language_reset
  end

  def create_customer_folders(folder_meta)
    3.times do
      company = create_company
      folder_meta.customer_folders.create(:customer_id => company.id)
    end
  end

  def quick_create_article
    category_meta = Solution::Builder.category(create_solution_category_alone(solution_default_params(:category)))
    folder_params = create_solution_folder_alone(solution_default_params(:folder).merge({:category_id => category_meta.id}))
    folder_meta = Solution::Builder.folder(folder_params)
    params = create_solution_article_alone(solution_default_params(:article, :title).merge({:folder_id => folder_meta.id}))
    article_meta = Solution::Builder.article(params.deep_symbolize_keys!)
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
      cat.reload
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
    solution_test_setup
  end

  def solutions_cache_key(account)
    MemcacheKeys::ALL_SOLUTION_CATEGORIES % { :account_id => account.id }
  end

  def check_cache_invalidation(account)
    $memcache.get(solutions_cache_key(account)).should be_nil
  end 

  def check_language_equality
    lang_obj = Language.find_by_code(@account.language)
    @account.make_current
    ["solution_categories", "solution_folders", "solution_articles"].each do |solution_assoc|
      check_language_by_assoc(solution_assoc, lang_obj)
    end
    Account.reset_current_account
  end

  def check_language_by_assoc sol_assoc, lang_obj
    @account.send("#{sol_assoc}").each do |obj|
      obj.language.should be_eql(lang_obj)
      obj.language_id.should be_eql(lang_obj.id)
    end
  end

  def create_portal(params = {})
    test_portal = FactoryGirl.build(:portal, 
                      :name=> params[:portal_name] || Faker::Name.name, 
                      :portal_url => params[:portal_url] || "", 
                      :language=>"en",
                      :forum_category_ids => (params[:forum_category_ids] || [""]),
                      :solution_category_metum_ids => (params[:solution_category_ids] || [""]),
                      :solution_category_metum_ids => (params[:solution_category_metum_ids] || 
                              params[:solution_category_ids] || [""]),
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
end