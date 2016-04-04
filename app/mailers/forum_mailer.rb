class ForumMailer < ActionMailer::Base

  include Helpdesk::NotifierFormattingMethods
  include Mailbox::MailerHelperMethods
  include Community::MailerHelper

  layout "email_font"
end