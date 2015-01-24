class PostMailer < ActionMailer::Base

  include Helpdesk::NotifierFormattingMethods
	include Mailbox::MailerHelperMethods

  layout "email_font"

  def monitor_email(emailcoll, post, user, portal, sender, host)
    configure_mailbox(user, portal)
    recipients    emailcoll
    from          sender
    subject       "[New Reply] in #{post.topic.title}"
    sent_on       Time.now
    content_type  "multipart/mixed"

    part :content_type => "multipart/alternative" do |alt|
      alt.part "text/plain" do |plain|
        plain.body  render_message("mailer/post/monitor_email.text.plain.erb", :post => post,:user => user,:host => host)
      end
      alt.part "text/html" do |html|
        html.body   Premailer.new(render_message("mailer/post/monitor_email.text.html.erb",:post => post, 
                                          :body_html => generate_body_html( post.body_html, [], post.account ), 
                                          :user => user,
                                          :account => post.account, 
                                          :host => host), 
                                  with_html_string: true, :input_encoding => 'UTF-8').to_inline_css
      end
    end
  end

end
