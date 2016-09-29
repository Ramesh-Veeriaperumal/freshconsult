module Helpdesk::Email::HandleArticle
  def create_article
  	article_params = {
                        :title => article_title(common_email_data[:subject]),
                        :description => common_email_data[:description_html],
                        :user => user.id,
                        :account => account.id,
                        :content_ids => common_email_data[:content_ids],
                        :attachment_info => common_email_data[:attachment_info],
                        :attachments => common_email_data[:attached_items]
                      }    
    Helpdesk::KbaseArticles.create_article_from_email(article_params)
    Rails.logger.info "Email Processing Successful: Email Successfully created as Article!!"
  end

  def article_title(text)
    text.gsub(Regexp.new("\\[#{account.ticket_id_delimiter}([0-9]*)\\]"),"")
  end
end