class Helpdesk::KbaseArticles
  extend Helpdesk::Utils::Attachment
  def self.create_article_from_email(article_params)  
    account = Account.find(article_params[:account])
    user = account.users.find(article_params[:user])

    if user.agent? or from_support_email?(user, account)
      article = add_knowledge_base_article(account, user, article_params[:title], article_params[:description])    
      create_article_attachments(article_params, article, account)
    end
  end
      
  def self.from_support_email?(user, account)
    account.email_configs.select{ |x| x.reply_email == user.email }.present?
  end

  def self.create_article_attachments(article_params, article, account)
    
    temp_body_html = String.new(article.description)
    content_ids = article_params[:content_ids] 
   
    article_params[:attachments].each_pair do |key,value|
      content_id = content_ids[key]
      description = "content_id" unless content_id.nil?
      created_attachment = {:content => value, :account_id => account.id, :description => description}
      created_attachment = create_attachment_from_params(article,created_attachment,nil,key)
      created_attachment.save
      temp_body_html.sub!("cid:#{content_id}",created_attachment.content.url)  unless content_id.nil?
    end

    unless content_ids.blank?
      article.update_attributes!(:description => temp_body_html)
    end
  end

  def self.create_article_from_note(account, user, title, description, attachments)
    article = add_knowledge_base_article(account, user, title, description)        

    (attachments || []).each do |attachment|
      article.attachments.create(:content => attachment[:resource], :account_id => article.account_id)
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