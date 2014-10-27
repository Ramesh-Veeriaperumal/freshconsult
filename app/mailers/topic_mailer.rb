class TopicMailer < ActionMailer::Base

  include Helpdesk::NotifierFormattingMethods
  include Mailbox::MailerHelperMethods
	
  def monitor_email(emailcoll, topic, user, portal, sender, host)
    configure_mailbox(user, portal)
    headers = {
      :to        => emailcoll,
      :from      => sender,
      :subject   => "[New Topic] in #{topic.forum.name}",
      :sent_on   => Time.now
    }
    inline_attachments = []
    @topic  = topic
    @user   = user
    @body_html = generate_body_html(topic.posts.first.body_html)
    @host = host

    if attachments.present? && attachments.inline.present?
      handle_inline_attachments(attachments, topic.posts.first.body_html, topic.account)
    end

    mail(headers) do |part|
      part.text { render "mailer/topic/monitor_email.text.plain" }
      part.html do 
        Premailer.new(
          render("mailer/topic/monitor_email.text.html"), 
          :with_html_string => true, 
          :input_encoding => 'UTF-8'
        ).to_inline_css 
      end
    end.deliver
  end

  def stamp_change_email(emailcoll, topic, user, current_stamp, forum_type, portal, sender, host)
    configure_mailbox(user, portal)
    headers = {
      :to => emailcoll,
      :from => sender,
      :subject => "[Status Update] in #{topic.title}",
      :sent_on => Time.now
    }

    @topic = topic
    @user = user
    @host = host 
    @current_stamp = current_stamp 
    @forum_type = forum_type
    @body_html = generate_body_html(topic.posts.first.body_html)

    mail(headers) do |part|
      part.text { render "mailer/topic/stamp_change_notification_email.text.plain" }
      part.html do
        Premailer.new(
          render("mailer/topic/stamp_change_notification_email.text.html"),
          with_html_string: true, 
          :input_encoding => 'UTF-8'
        ).to_inline_css
      end
    end.deliver
  end


  # TODO-RAILS3 Can be removed oncewe fully migrate to rails3
  # Keep this include at end
  include MailerDeliverAlias
end