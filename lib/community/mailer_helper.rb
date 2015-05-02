module Community::MailerHelper

  def notify_new_follower(object, user, portal, monitorship)
    mail_config = portal.primary_email_config || user.account.primary_email_config
    self.class.set_mailbox mail_config.smtp_mailbox
    sender = monitorship.sender_and_host[0]
    headers = {
      :to        => monitorship.user.email,
      :from      => sender,
      :subject   => new_follower_subject(object),
      :sent_on   => Time.now
    }
    o_type = object.class.name.downcase
    instance_variable_set("@#{o_type}", object)
    @user   = user
    @account = object.account
    @monitorship = monitorship
    @portal = portal

    mail(headers) do |part|
      part.text { render "mailer/#{o_type}/new_follower.text.plain" }
      part.html do
        Premailer.new(
          render("mailer/#{o_type}/new_follower.text.html"), 
          :with_html_string => true, 
          :input_encoding => 'UTF-8'
        ).to_inline_css 
      end
    end.deliver 
  end

  def new_follower_subject(object)
    "Added as #{object.class.name} Follower - #{object[:name] || object[:title]}"
  end
end