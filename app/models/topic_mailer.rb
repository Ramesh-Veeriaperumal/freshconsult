class TopicMailer < ActionMailer::Base

  include Helpdesk::NotifierFormattingMethods
  include Mailbox::MailerHelperMethods
	
  def monitor_email(emailcoll, topic, user, portal, sender, host)
    configure_mailbox(user, portal)
    recipients    emailcoll
    from          sender
    subject       "[New Topic] in #{topic.forum.name}"
    sent_on       Time.now
    content_type  "multipart/mixed"

    part :content_type => "multipart/alternative" do |alt|
      alt.part "text/plain" do |plain|
        plain.body  render_message("mailer/topic/monitor_email.text.plain.erb", :topic => topic,:user => user, :host => host)
      end
      alt.part "text/html" do |html|
        html.body   Premailer.new(render_message("mailer/topic/monitor_email.text.html.erb",
                                    :topic => topic, 
                                    :body_html => generate_body_html( topic.posts.first.body_html, [], topic.account ), 
                                    :user => user, :host => host
                                  ), :with_html_string => true, :input_encoding => 'UTF-8').to_inline_css
      end
    end
  end

  def stamp_change_email(emailcoll, topic, user, current_stamp, forum_type, portal, sender, host)
    configure_mailbox(user, portal)
    recipients    emailcoll
    from          sender
    subject       "[Status Update] in #{topic.title}"
    sent_on       Time.now
    content_type  "multipart/mixed"

    part :content_type => "multipart/alternative" do |alt|
      alt.part "text/plain" do |plain|
        plain.body  render_message("mailer/topic/stamp_change_notification_email.text.plain.erb", :topic => topic,:user => user, :host => host, :current_stamp => current_stamp, :forum_type => forum_type)
      end
      alt.part "text/html" do |html|
        html.body   Premailer.new(render_message("mailer/topic/stamp_change_notification_email.text.html.erb",
                                    :topic => topic, 
                                    :body_html => generate_body_html( topic.posts.first.body_html, [], topic.account ), 
                                    :user => user, :host => host, 
                                    :current_stamp => current_stamp, :forum_type => forum_type
                                  ), with_html_string: true, :input_encoding => 'UTF-8').to_inline_css
      end
    end
  end

  def topic_merge_email(monitor, target_topic, source_topic, sender, host)
    configure_mailbox(monitor.user, monitor.get_portal)
    recipients    monitor.user.email
    from          sender
    subject       "[Topic Merged] to #{target_topic.title}"
    sent_on       Time.now
    content_type  "multipart/mixed"

    part :content_type => "multipart/alternative" do |alt|
      alt.part "text/plain" do |plain|
        plain.body  render_message("mailer/topic/merge_topic_notification_email.text.plain.erb", 
                            :source_topic => source_topic, 
                            :target_topic => target_topic, 
                            :user => monitor.user, 
                            :host => host, 
                            :portal => monitor.get_portal)
      end
      alt.part "text/html" do |html|
        html.body   Premailer.new(render_message("mailer/topic/merge_topic_notification_email.text.html.erb",
                            :source_topic => source_topic, 
                            :target_topic => target_topic, 
                            :user => monitor.user, 
                            :host => host, 
                            :portal => monitor.get_portal), 
                            with_html_string: true, :input_encoding => 'UTF-8').to_inline_css
      end
    end
  end
end