class Notifications::Email::BccDecorator < ApiDecorator
  delegate :bcc_email, to: :record

  def to_hash
    {
      emails: bcc_emails
    }
  end

  def bcc_emails
    if bcc_email
      bcc_email.split(',')
    else
      []
    end
  end
end
