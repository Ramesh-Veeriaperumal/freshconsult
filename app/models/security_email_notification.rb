class SecurityEmailNotification < ActionMailer::Base

  layout "email_font"

  def agent_alert_mail(model, subject, changed_attributes)
    Time.zone = model.time_zone
    recipients    model.email
    from          Account.current.default_friendly_email
    subject       subject
    content_type  "multipart/mixed"
    headers       "Auto-Submitted" => "auto-generated", "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    part :content_type => "multipart/alternative" do |alt|
      alt.part "text/plain" do |plain|
        plain.body   render_message("agent_alert_mail.text.plain.erb", :model => model, :changes => changed_attributes, 
          :time => Time.zone.now.strftime('%B %e at %l:%M %p %Z') )
      end

      alt.part "text/html" do |html|
        html.body   render_message("agent_alert_mail.text.html.erb", :model => model, :changes => changed_attributes, 
          :time => Time.zone.now.strftime('%B %e at %l:%M %p %Z'), :account => Account.current)
      end
    end
  end

  def admin_alert_mail(model, subject, body_message_file, changed_attributes)
    Time.zone = Account.current.time_zone
    recipients    Account.current.notification_emails
    from          AppConfig['from_email']
    subject       subject
    content_type  "multipart/mixed"
    headers       "Auto-Submitted" => "auto-generated", "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    part :content_type => "multipart/alternative" do |alt|
      alt.part "text/plain" do |plain|
        plain.body   render_message("#{body_message_file}.text.plain.erb", :model => model, :changes => changed_attributes, 
          :time => Time.zone.now.strftime('%B %e at %l:%M %p %Z') )
      end

      alt.part "text/html" do |html|
        html.body   render_message("#{body_message_file}.text.html.erb", :model => model, :changes => changed_attributes, 
          :time => Time.zone.now.strftime('%B %e at %l:%M %p %Z'), :account => Account.current )
      end
    end
  end

end
