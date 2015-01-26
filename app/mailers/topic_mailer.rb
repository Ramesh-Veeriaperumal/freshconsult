class TopicMailer < ActionMailer::Base

  include Helpdesk::NotifierFormattingMethods
  include Mailbox::MailerHelperMethods

  layout "email_font"
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
    @account = topic.account

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
    
    inline_attachments =[]
    @topic = topic
    @user = user
    @host = host 
    @current_stamp = current_stamp 
    @forum_type = forum_type
    @body_html = generate_body_html(topic.posts.first.body_html)
    @account = topic.account

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

  def topic_merge_email(monitor, target_topic, source_topic, sender, host)
    configure_mailbox(monitor.user, monitor.get_portal)
    headers = {
      :to => monitor.user.email,
      :from => sender,
      :subject => "[Topic Merged] to #{target_topic.title}",
      :sent_on => Time.now
    }

    @source_topic = source_topic
    @target_topic = target_topic
    @user = monitor.user
    @host = host
    @portal = monitor.get_portal
    @account = Account.current
    mail(headers) do |part|
      part.text do
        render("mailer/topic/merge_topic_notification_email.text.plain")
      end
      part.html do
        Premailer.new(render("mailer/topic/merge_topic_notification_email.text.html"), 
                            with_html_string: true, :input_encoding => 'UTF-8').to_inline_css
      end
    end.deliver
  end


  # TODO-RAILS3 Can be removed oncewe fully migrate to rails3
  # Keep this include at end
  include MailerDeliverAlias
end