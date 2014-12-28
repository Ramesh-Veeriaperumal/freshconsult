class SpamDigestMailer < ActionMailer::Base
  
  layout "email_font"
  
  def spam_digest(options={}) 
    recipients    options[:recipients]
    from          Helpdesk::EMAIL[:from]
    subject       options[:subject]
    sent_on       Time.now
    body          Premailer.new(render_message("spam_digest_mailer/spam_digest.html.erb", :account => options[:account],
                    :moderation_digest => options[:moderation_digest], :moderator => options[:moderator],
                    :host => options[:host]), with_html_string: true, :input_encoding => 'UTF-8').to_inline_css
    content_type  "text/html"
  end 
end