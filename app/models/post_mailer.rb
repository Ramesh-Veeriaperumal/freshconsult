class PostMailer < ActionMailer::Base
	
  def monitor_email(emailcoll,post,user)
    recipients    emailcoll
    from          user.account.default_friendly_email
    subject       post.topic.title
    sent_on       Time.now
    content_type  "multipart/mixed"

    part :content_type => "multipart/alternative" do |alt|
      alt.part "text/plain" do |plain|
        plain.body  render_message("monitor_email.text.plain.erb", :post => post,:user => user)
      end
      alt.part "text/html" do |html|
        html.body   render_message("monitor_email.text.html.erb",:post => post,:user => user)
      end
    end

  end 
  

end
