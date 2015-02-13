class DraftMailer < ActionMailer::Base

	include Mailbox::MailerHelperMethods
	include Helpdesk::NotifierFormattingMethods

  layout "email_font"

	def self.draft_discard_notification(draft, article, created_author, current_user, portal)
		deliver_draft_discard_email(draft, article, created_author, current_user, portal)
	end
	
  def draft_discard_email(draft, article, created_author, current_user, portal)
    mail_config = portal.primary_email_config || current_user.account.primary_email_config
    self.class.set_mailbox mail_config.smtp_mailbox

    headers = {
      :to        => created_author.email,
      :from      => current_user.email,
      :subject   => "[Draft Discarded] #{draft[:title]}",
      :sent_on   => Time.now
    }

    @draft = draft
    @article = article
    @created_author = created_author
    @user = current_user
    @host = portal.host
    @body_html = generate_body_html(draft[:description])

    mail(headers) do |part|
      part.text { render "mailer/draft/draft_discard_email.text.plain.erb" }
      part.html do 
        Premailer.new(
          render("mailer/draft/draft_discard_email.text.html.erb"), 
          :with_html_string => true, 
          :input_encoding => 'UTF-8'
        ).to_inline_css 
      end
    end.deliver
    
  end

end