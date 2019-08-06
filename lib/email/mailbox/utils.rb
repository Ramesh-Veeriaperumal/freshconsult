module Email::Mailbox::Utils
  def construct_to_email(to_email, account_full_domain)
     email_split  = to_email.split('@')
     email_name   = email_split[0] || ''
     email_domain = email_split[1] || ''

     account_full_domain = account_full_domain.downcase
     reply_email  = '@' + account_full_domain

     if(email_domain.downcase == account_full_domain)
        reply_email = email_name + reply_email
     else
        reply_email = email_domain.gsub(/\./,'') + email_name + reply_email
     end
     reply_email
  end
end