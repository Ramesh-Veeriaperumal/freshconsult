class PostMailer < ActionMailer::Base

  include Helpdesk::NotifierFormattingMethods
  include Mailbox::MailerHelperMethods

  layout "email_font"

  def monitor_email(emailcoll, post, user, portal, sender, host)
    configure_mailbox(user, portal)
    headers        = {
      :to      => emailcoll,
      :from    => sender,
      :subject => "[New Reply] in #{post.topic.title}",
      :sent_on => Time.now
    }

    inline_attachments = []
    @post = post
    @user = user
    @body_html = generate_body_html(post.body_html)
    @host = host
    @account = post.account

    if attachments.present? && attachments.inline.present?
      handle_inline_attachments(attachments, post.body_html, post.account)
    end
    
    mail(headers) do |part|
      part.text do 
        render "mailer/post/monitor_email.text.plain"
      end
      part.html do
        Premailer.new(
          render("mailer/post/monitor_email.text.html"),
          :with_html_string => true, 
          :input_encoding => 'UTF-8'
        ).to_inline_css
      end
    end.deliver
  end 
end
