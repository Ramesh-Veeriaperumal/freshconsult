class Helpdesk::KbaseArticles

  def self.create_article_from_email(article_params)  
    account = Account.find(article_params[:account])
    user = account.users.find(article_params[:user])
    
    if user.agent?
      article = add_knowledge_base_article(account, user, article_params[:title], article_params[:description])        
      create_article_attachments(article_params, article)
    end
  end
      
  def self.create_article_attachments(article_params, article)
    
    temp_body_html = String.new(article.description)
    content_ids = article_params[:content_ids] 
   
    article_params[:attachments].each_pair do |key,value|
      created_attachment = article.attachments.create(:content => value, :account_id => account.id)
      content_id = content_ids[key]
      temp_body_html = temp_body_html.sub!("cid:#{content_id}",created_attachment.content.url)  unless content_id.nil?
    end

    unless content_ids.blank?
      article.update_attributes!(:description => temp_body_html)
    end
  end

  def self.create_article_from_note(account, user, title, description, attachments)
    article = add_knowledge_base_article(account, user, title, description)        

    (attachments || []).each do |attachment|
      article.attachments.create(:content => attachment[:file], :description => attachment[:description], :account_id => article.account_id)
    end
  end

  def self.add_knowledge_base_article(account, user, title, description) 
    
    default_category = account.solution_categories.find_by_is_default(true)
    default_folder = default_category.folders.find_by_is_default(true) if default_category
    
    
    if default_folder
      article = default_folder.articles.build(
        :title => title,
        :description => description,
        :status => Solution::Article::STATUS_KEYS_BY_TOKEN[:draft],
        :art_type => Solution::Article::TYPE_KEYS_BY_TOKEN[:permanent]
      )
      article.user = user
      article.account = account
      article.save
      article
    end
  end

end