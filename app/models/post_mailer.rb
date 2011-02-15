class PostMailer < ActionMailer::Base
  
  def monitor_email(emailcoll,post,user)
    bcc    emailcoll
    from          "support@freshdesk.com"
    subject       post.topic.title
    sent_on       Time.now
    body(:post => post,:user => user)
    content_type  "text/html"
  end 
  

end
