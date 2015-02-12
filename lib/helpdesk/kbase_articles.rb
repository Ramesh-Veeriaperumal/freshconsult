class Helpdesk::KbaseArticles
  extend Helpdesk::Utils::Attachment

  class << self

    def create_article_from_email(article_params)  
      account = Account.find(article_params[:account])
      user = account.users.find(article_params[:user])

      if user.agent? or from_support_email?(user, account)
        article = add_knowledge_base_article(account, user, article_params[:title], article_params[:description])    
        create_article_attachments(article_params, article, account)
      end
    end

    def from_support_email?(user, account)
      account.email_configs.select{ |x| x.reply_email == user.email }.present?
    end

    def create_article_attachments(article_params, article, account)
      
      temp_body_html = String.new(article.description)
      content_ids = article_params[:content_ids] 
     
      article_params[:attachments].each_pair do |key,value|

        content_id = content_ids[key]

        attachment = {
          :content => value, 
          :account_id => account.id, 
          :description => content_id.present? ? 'content_id' : ''
        }

        attachment = create_attachment(content_id.present? ? account : article, attachment, key, content_id.present?)
        attachment.save
        temp_body_html.sub!("cid:#{content_id}", attachment.content.url) if content_id.present?
      end

      unless content_ids.blank?
        article.update_attributes!(:description => temp_body_html)
      end
    end

    def create_attachment(parent, created_attachment, name, inline)
      if inline
        created_attachment.merge!({:attachable_type => "Image Upload"})
        parent.attachments.build(created_attachment)
      else
        create_attachment_from_params(parent, created_attachment, nil, name)
      end
    end

    def create_article_from_note(account, user, title, description, attachments)
      article = add_knowledge_base_article(account, user, title, description)        

      (attachments || []).each do |attachment|
        article.attachments.create(:content => attachment[:resource], :account_id => article.account_id)
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
        article.save
        create_draft(article)
        article
      end
    end

    def self.create_draft(article)
      draft = article.build_draft(:status => Solution::Draft::STATUS_KEYS_BY_TOKEN[:work_in_progress])
      draft.save
    end

  end
end