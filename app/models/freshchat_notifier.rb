class FreshchatNotifier < ActionMailer::Base
  layout "email_font"

  def freshchat_email_template(account, params)
    subject      params[:subject]
    recipients   params[:recipients]
    from         params[:from]
    headers      "Reply-to" => "","Auto-Submitted" => "auto-generated", "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    cc           params[:cc] if params[:cc].present?
    body         :account => account, :message => params[:message]
    sent_on      Time.now
    content_type "text/html"
  end
  
end