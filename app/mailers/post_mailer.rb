class PostMailer < ActionMailer::Base

  include Helpdesk::NotifierFormattingMethods
  include Mailbox::MailerHelperMethods
  include EmailHelper

  layout "email_font"

  def monitor_email(emailcoll, post, user, portal, sender, host)
    begin
      configure_mailbox(user, portal)
      email_config = Thread.current[:email_config]
      headers        = {
        :to      => emailcoll,
        :from    => sender,
        :subject => I18n.t('mailer_notifier_subject.monitor_email_subject', post_topic: post.topic.title),
        :sent_on => Time.now
      }

      headers.merge!(make_header(nil, nil, post.account_id, "Monitor Email"))
      headers.merge!({"X-FD-Email-Category" => email_config.category}) if email_config.category.present?
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
    ensure
      remove_email_config
    end
  end 
end
