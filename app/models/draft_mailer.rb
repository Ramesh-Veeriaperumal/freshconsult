class DraftMailer < ActionMailer::Base

  include Mailbox::MailerHelperMethods
  include Helpdesk::NotifierFormattingMethods

  layout "email_font"

  def self.discard_notification(draft, article, current_author, current_user, portal)
    discard_email(draft, article, current_author, current_user, portal)
  end

  def discard_email(draft, article, current_author, current_user, portal)
    mail_config = portal.primary_email_config || current_user.account.primary_email_config
    self.class.set_mailbox mail_config.smtp_mailbox

    headers = {
      :to        => current_author.email,
      :from      => current_user.email,
      :subject   => "[Draft Discarded] #{draft[:title]}",
      :sent_on   => Time.now
    }

    @draft = draft
    @article = article
    @current_author = current_author
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