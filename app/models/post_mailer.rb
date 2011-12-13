class PostMailer < ActionMailer::Base
  
  def monitor_email(emailcoll,post,user)
    recipients    emailcoll
    from          user.account.default_friendly_email
    subject       post.topic.title
    sent_on       Time.now
    body(:post => post,:user => user)
    content_type  "text/html"
  end 
  

end
