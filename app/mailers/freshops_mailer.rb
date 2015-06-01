class FreshopsMailer < ActionMailer::Base
  default from: "admin@freshdesk.com"

  def subscription_summary_csv(email_id,email_params,csv_file)
    headers = {
      :subject    => "Subscription Summary for #{email_params[:period]}",
      :to         => email_id,
      :sent_on    => Time.now,
      :body       => "Hi #{email_params[:name]},
      	The Subscription Summary for #{email_params[:event_type]} has been attached."
    }
    attachments['subscription_summary.csv'] = {
    	:mime_type => 'application/csv; charset=utf-8; header=present',
    	:content   => csv_file
    }
    mail(headers).deliver
  end

end
