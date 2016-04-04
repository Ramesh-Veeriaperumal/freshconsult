class SpamDigestMailer < ActionMailer::Base
  
  layout "email_font"
  
  def spam_digest(options={}) 
    headers        = {
      :to      => options[:recipients],
      :from    => Helpdesk::EMAIL[:from],
      :subject => options[:subject],
      :sent_on => Time.now,
      :content_type => "text/html"
    }

    @moderation_digest = options[:moderation_digest]
    @moderator = options[:moderator]
    @host = options[:host]
    @account = options[:account]

    mail(headers) do |part|
      part.html do
        Premailer.new(render("spam_digest_mailer/spam_digest"), 
          with_html_string: true, :input_encoding => 'UTF-8').to_inline_css
      end
    end.deliver
  end 
end