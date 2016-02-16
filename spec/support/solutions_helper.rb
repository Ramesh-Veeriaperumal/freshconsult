module SolutionsHelper

  def create_category(params = {})
    c_params = create_solution_category_alone(solution_default_params(:category, :name, {
      :name => params[:name],
      :description => params[:description]
    }))
    c_params[:solution_category_meta][:is_default] = params[:is_default] if params[:is_default].present?
    category_meta = Solution::Builder.category(c_params)
    category_meta
  end

  def create_folder(params = {})
    params = create_solution_folder_alone(solution_default_params(:folder, :name, {
        :name => params[:name],
        :description => params[:description]
      }).merge({
        :category_id => params[:category_meta_id] || params[:category_id],
        :visibility => params[:visibility]
      }))
    folder_meta = Solution::Builder.folder(params)
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
    article_meta = Solution::Builder.article(params.deep_symbolize_keys)
    article_meta
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

  def check_meta_integrity(object)
    meta_obj = object.reload.meta_object
    meta_obj.should be_an_instance_of(object.meta_class)
    object.common_meta_attributes.each do |attrib|
      meta_obj.send(attrib).should be_eql(object.read_attribute(attrib))
      meta_obj.send(attrib).should be_eql(object.send(attrib))
    end
    parent_keys = object.assign_keys
    meta_obj.account_id.should be_eql(object.account_id)
    meta_obj.send(parent_keys.first).should be_eql(object.send(parent_keys.last))
  end

  def check_position(parent, assoc_name)
    parent.reload.send(assoc_name).each do |obj|
      meta_assoc = obj.meta_association
      obj.position.should be_eql(obj.send(meta_assoc).position) if obj.send(meta_assoc).present?
      obj.read_attribute(:position).should be_eql(obj.send(meta_assoc).position) if obj.send(meta_assoc).present?
    end
  end

  def check_meta_assoc_equality(obj)
    obj.class::FEATURE_BASED_METHODS.each do |meth|
      @account.rollback(:meta_read)
      reload_objects_and_models(obj)
      result1 = obj.send("#{meth}")
      @account.launch(:meta_read)
      reload_objects_and_models(obj)
      result2 = obj.send("#{meth}")
      result1.should == result2
    end
  end

  def check_meta_delegates(obj)
    obj.meta_class::COMMON_ATTRIBUTES.each do |attrib|
      @account.rollback(:meta_read)
      reload_objects_and_models(obj)
      result1 = obj.send("#{attrib}")
      @account.launch(:meta_read)
      reload_objects_and_models(obj)
      result2 = obj.send("#{attrib}")
      result1.should == result2
    end
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
    @account.send("#{sol_assoc}_without_association").each do |obj|
      obj.language.should be_eql(lang_obj)
      obj.language_id.should be_eql(lang_obj.id)
    end
  end

  def reload_objects_and_models(obj)
    @account.reload
    @account.make_current
    obj.reload
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
  
  def hit_action_and_fetch(controller_name, object, instance_var_name, action_name = :show, meth_name = :get)
    @controller = controller_name.constantize.new
    send(meth_name, action_name, :id => object.id)
    multilingual = controller_name.include?("Multilingual")
    resp_class = multilingual ? object.meta_class : object.class
    instance_variable_set((multilingual ? "@multilingual_resp" : "@normal_resp"), response.body)
    resp_obj = controller.instance_variable_get("@#{instance_var_name}")
    resp_obj.should be_an_instance_of(resp_class)
    resp_obj
  end
  
  def check_multilingual_mobihelp_voting(object, vote_type)
    thumbs_up = object.send(vote_type)
    article_meta = hit_action_and_fetch("Mobihelp::Multilingual::ArticlesController",
         object, "article", vote_type, :put)
    article = hit_action_and_fetch("Mobihelp::ArticlesController", object, 
        "article", vote_type, :put)
    article_meta.id.should eql(article.id)
    article_meta.reload.send(vote_type).should eql(thumbs_up+2)
    article.reload.send(vote_type).should eql(thumbs_up+2)
    article_meta.send(vote_type).should eql(article.send(vote_type))
  end
  
  MOBIHELP_DONT_COMPARE = ["created_at", "updated_at", "modified_at", "delta"]

  def compare_mobihelp_response(normal_resp, multilingual_resp)
    normal_resp.length.should eql(multilingual_resp.length)
    normal_resp.zip(multilingual_resp).each do |normal, multilingual|
      normal_folder = normal["folder"]
      multilingual_folder = multilingual["folder"]
      compare_hash_keys(normal_folder, multilingual_folder)
    end
  end
  
  def compare_hash_keys normal_hash, multilingual_hash
    (normal_hash.keys - Solution::ApiDelegator::API_ALWAYS_REMOVE.map(&:to_s)).should eql(multilingual_hash.keys)
    (normal_hash.keys - (MOBIHELP_DONT_COMPARE + Solution::ApiDelegator::API_ALWAYS_REMOVE.map(&:to_s))).each do |key|
      if normal_hash[key].is_a?(Array) && normal_hash[key].first.is_a?(Hash)
        normal_hash[key].zip(multilingual_hash[key]).each do |normal_assoc, multilingual_assoc|
          compare_hash_keys(normal_assoc, multilingual_assoc)
        end
      elsif normal_hash[key].is_a?(Hash)
        compare_hash_keys(normal_hash[key], multilingual_hash[key])
      else
        normal_hash[key].should eql(multilingual_hash[key])
      end
    end
  end
  
  def check_solution_portal_drop_methods(portal)
    PortalDrop::FEATURE_BASED_METHODS.each do |method|
      @account.launch(:solutions_meta_read)
      @account.reload
      @account.make_current
      portal_drop_object = PortalDrop.new(portal)
      objects_thru_meta = portal_drop_object.send(method)
      @account.rollback(:solutions_meta_read)
      @account.reload
      @account.make_current
      portal.reload
      portal_drop_object = PortalDrop.new(portal)
      obj = portal_drop_object.send(method)
      obj.sort_by!(&:modified_at).reverse! if method == :recent_articles
      if objects_thru_meta.is_a?(Array) || objects_thru_meta.is_a?(ActiveRecord::Relation)
        meta_class = "Solution::#{method.to_s.split('_').last.singularize.capitalize}Meta"
        klass = meta_class.gsub("Meta", "")
        objects_thru_meta.map { |x| x.should be_an_instance_of(meta_class.constantize) }
        obj.map { |x| x.should be_an_instance_of(klass.constantize) }
        if method == :recent_articles 
          objects_thru_meta.map(&:id).sort.should eql(obj.map(&:id).sort)
        else
          objects_thru_meta.map(&:id).should eql(obj.map(&:id))
        end
      else
        objects_thru_meta.should eql(obj)
      end 
    end
  end
end