module Helpdesk::ArticlesUtility

  def create_article_from_email(account, from_email, to_email)
    
    email_config = account.email_configs.find_by_to_email(to_email[:email])
    user = get_user(account, from_email,email_config)
    
    return if user.blocked? # Article is not created if the user is blocked

    if user.agent?
      title = params[:subject].gsub(/\[#([0-9]*)\]/,"")
      description = Helpdesk::HTMLSanitizer.clean(params[:html]) || params[:text]
      
      article = add_knowledge_base_article(account, user, title, description)   
      
      create_article_attachments(account, article)
    end
  end
      
  def create_article_from_note
    kbase_email = "kbase@#{current_account.full_domain}"
    if ((params[:bcc_emails].include?(kbase_email)) || (params[:cc_emails].include?(kbase_email)))
      params[:bcc_emails].delete(kbase_email)
      params[:cc_emails].delete(kbase_email)
      
      body_html = params[:helpdesk_note][:body_html]
      attachments = params[:helpdesk_note][:attachments]
      article = add_knowledge_base_article(current_account, current_user, @parent.subject, body_html)        

      (attachments || []).each do |attachment|
        article.attachments.create(:content => attachment[:file], :description => attachment[:description], :account_id => article.account_id)
      end
    end
  end

  def add_knowledge_base_article(account, user, title, description) 
    
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
      article.save!
      article
    end
  end

  def create_article_attachments(account, article)
    temp_body_html = String.new(article.description)
    content_ids = params["content-ids"].nil? ? {} : get_content_ids 
   
    Integer(params[:attachments]).times do |i|
      created_attachment = article.attachments.create(:content => params["attachment#{i+1}"], :account_id => account.id)
      content_id = content_ids["attachment#{i+1}"]
      temp_body_html = temp_body_html.sub!("cid:#{content_id}",created_attachment.content.url)  unless content_id.nil?
    end

    unless content_ids.blank?
      article.update_attributes!(:description => temp_body_html)
    end
  end
  
end