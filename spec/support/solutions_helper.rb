module SolutionsHelper

  def create_category(params = {})
    test_category = FactoryGirl.build(:solution_categories, :name => params[:name] || Faker::Name.name,
              :description => params[:description], :is_default => params[:is_default])
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
    
    article_obj.read_attribute(:description).should be_eql(art_description)
    article_obj.description.should be_eql(art_description)
    article_obj[:description].should be_eql(art_description)

    article_obj.read_attribute(:desc_un_html).strip.should be_eql(art_description_text)
    article_obj.desc_un_html.strip.should be_eql(art_description_text)
    article_obj[:desc_un_html].strip.should be_eql(art_description_text)

    Solution::Article::BODY_ATTRIBUTES.each do |attrib|
      article_body.send(attrib).should be_eql(article_obj.read_attribute(attrib))
    end
  end
end