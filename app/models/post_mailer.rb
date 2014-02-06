class PostMailer < ActionMailer::Base

  include Helpdesk::NotifierFormattingMethods
	
  def monitor_email(emailcoll,post,user)
    self.class.set_mailbox user.account.primary_email_config.smtp_mailbox
    recipients    emailcoll
    from          user.account.default_friendly_email
    subject       "[New Reply] #{post.topic.title}"
    sent_on       Time.now
    content_type  "multipart/mixed"

    inline_attachments = []

    part :content_type => "multipart/alternative" do |alt|
      alt.part "text/plain" do |plain|
        plain.body  render_message("monitor_email.text.plain.erb", :post => post,:user => user)
      end
      alt.part "text/html" do |html|
        html.body   render_message("monitor_email.text.html.erb",:post => post, 
                                    :body_html => generate_body_html( post.body_html, inline_attachments, post.account ), :user => user)
      end
    end

    handle_inline_attachments(inline_attachments) unless inline_attachments.blank?
  end 
end
