class DraftMailer < ActionMailer::Base

  include Mailbox::MailerHelperMethods
  include Helpdesk::NotifierFormattingMethods
  include EmailHelper

  layout "email_font"

  def self.discard_notification(draft, article, current_author, current_user, portal)
    discard_email(draft, article, current_author, current_user, portal)
  end

  def discard_email(draft, article, current_author, current_user, portal)
    mail_config = portal.primary_email_config || current_user.account.primary_email_config
    begin
      configure_email_config mail_config

      headers = {
        :to        => current_author.email,
        :from      => current_user.email,
        :subject   => "[Draft Discarded] #{draft[:title]}",
        :sent_on   => Time.now
      }

      headers.merge!(make_header(nil, nil, current_user.account_id, "Discard Email"))
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
    ensure
      remove_email_config
    end
  end

end
