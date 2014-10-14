class FreshchatNotifier < ActionMailer::Base
  layout "email_font"

  def freshchat_email_template(account, params)
    headers = {
                :subject      =>  params[:subject],
                :recipients   =>  params[:recipients],
                :from         =>  params[:from],
                :sent_on      =>  Time.now,
                :content_type =>  "text/html",
                "Reply-to" => "",
                "Auto-Submitted" => "auto-generated", 
                "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
              }
    headers[:cc] = params[:cc] if params[:cc].present?
    @account = account
    @message = params[:message]
  end
end
