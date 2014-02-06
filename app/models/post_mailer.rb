class PostMailer < ActionMailer::Base

  include Helpdesk::NotifierFormattingMethods
	
  def monitor_email(emailcoll,post,user)
    recipients    emailcoll
    from          user.account.default_friendly_email
    subject       "[New Reply] in #{post.topic.title}"
    sent_on       Time.now
    content_type  "multipart/mixed"

    inline_attachments = []

    part :content_type => "multipart/alternative" do |alt|
      alt.part "text/plain" do |plain|
        plain.body  render_message("mailer/post/monitor_email.text.plain.erb", :post => post,:user => user)
      end
      alt.part "text/html" do |html|
        html.body   Premailer.new(render_message("mailer/post/monitor_email.text.html.erb",:post => post, 
                                    :body_html => generate_body_html( post.body_html, inline_attachments, post.account ), :user => user), with_html_string: true).to_inline_css
      end
    end

    handle_inline_attachments(inline_attachments) unless inline_attachments.blank?
  end 
end
