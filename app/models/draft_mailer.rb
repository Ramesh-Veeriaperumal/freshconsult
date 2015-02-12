class DraftMailer < ActionMailer::Base

	include Mailbox::MailerHelperMethods
	include Helpdesk::NotifierFormattingMethods

	def self.draft_discard_notification(draft, article, created_author, current_user, portal)
		deliver_draft_discard_email(draft, article, created_author, current_user, portal)
	end
	
  def draft_discard_email(draft, article, created_author, current_user, portal)
    mail_config = portal.primary_email_config || current_user.account.primary_email_config
    self.class.set_mailbox mail_config.smtp_mailbox

    subject       "[Draft Discarded] #{draft[:title]}"
    recipients    created_author.email
    from          current_user.email
    sent_on       Time.now
    content_type  "multipart/mixed"

    part :content_type => "multipart/alternative" do |alt|
      alt.part "text/plain" do |plain|
        plain.body  render_message("/mailer/draft/draft_discard_email.text.plain.erb", 
        	:draft => draft, :article => article, :created_author => created_author, :user => current_user, :host => portal.host)
      end
      alt.part "text/html" do |html|
        html.body   Premailer.new(render_message("/mailer/draft/draft_discard_email.text.html.erb",
                                    :draft => draft, 
                                    :article => article,
                                    :created_author => created_author,
                                    :body_html => generate_body_html( draft[:description], [], article.account),
                                    :user => current_user,
                                    :host => portal.host
                                  ), :with_html_string => true, :input_encoding => 'UTF-8').to_inline_css
      end
    end
  end

end