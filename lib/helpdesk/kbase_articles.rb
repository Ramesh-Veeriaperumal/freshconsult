class Helpdesk::KbaseArticles
  extend Helpdesk::Utils::Attachment

  class << self

    def create_article_from_email(article_params)
      article = nil  
      account = Account.find(article_params[:account])
      user = account.users.find(article_params[:user])

      if (user.agent? && user.privilege?(:create_and_edit_article)) or from_support_email?(user, account)
        article = add_knowledge_base_article(account, user, article_params[:title], article_params[:description])    
        create_article_attachments(article_params, article, account)
      end
      return article
    end

    def from_support_email?(user, account)
      account.email_configs.select{ |x| x.reply_email == user.email }.present?
    end

    def create_article_attachments(article_params, article, account)
      temp_body_html = String.new(article.description)
      content_ids = article_params[:content_ids] 
     
      article_params[:attachments].each_pair do |key,value|

        content_id = content_ids[key]
        inline = temp_body_html.include?("cid:#{content_id}") && !value.content_type.include?("svg")

        attachment = {
          :content => value, 
          :account_id => account.id, 
          :description => inline ? 'content_id' : ''
        }

        attachment = create_attachment(inline ? account : article, attachment, key, inline)
        attachment.save
        temp_body_html.sub!("cid:#{content_id}", attachment.content.url) if inline
      end
      
      unless content_ids.blank?
        article.draft.update_attributes!(:description => temp_body_html)
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
      
      default_category_meta = account.solution_category_meta.find_by_is_default(true)
      default_folder_meta = default_category_meta.solution_folder_meta.find_by_is_default(true) if default_category_meta
            
      if default_folder_meta
        article_meta = Solution::Builder.article(
          {
            :solution_article_meta => {
              :primary_article => {
                :title => title,
                :description => description,
                :status => Solution::Article::STATUS_KEYS_BY_TOKEN[:draft],
                :user_id => user.id
              },
              :art_type => Solution::Article::TYPE_KEYS_BY_TOKEN[:permanent],
              :solution_folder_meta_id => default_folder_meta.id
            }
          }  
        )
        article_meta.account = account
        article_meta.save
        article_meta.reload.primary_article
      end
    end
  end
end
