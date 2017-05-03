class FreshopsMailer < ActionMailer::Base
  default from: "admin@freshdesk.com"
  RECIPIENTS = "dev-ops@freshdesk.com"

  def subscription_summary_csv(email_id,email_params,csv_file)
    headers = {
      :subject    => "Subscription Summary for #{email_params[:period]}",
      :to         => email_id,
      :sent_on    => Time.now,
      :body       => "Hi #{email_params[:name]},
      	The Subscription Summary for #{email_params[:event_type]} for #{email_params[:region]} region has been attached."
    }
    attachments['subscription_summary.csv'] = {
    	:mime_type => 'application/csv; charset=utf-8; header=present',
    	:content   => csv_file
    }
    mail(headers).deliver
  end

  def freshfone_stats_summary_csv(email_params,csv_file)
    headers = {
      :subject    => "Freshfone #{email_params[:export_type].capitalize} Status",
      :to         => email_params[:email],
      :sent_on    => Time.now,
      :body       => "Hi #{email_params[:name]},
      The Freshfone #{email_params[:export_type]} status has been attached."
    }
    attachments[email_params[:export_type]+'_summary.csv'] = {
      :mime_type => 'application/csv; charset=utf-8; header=present',
      :content   => csv_file
    }
    mail(headers).deliver
  end

  def inconsistent_accounts_summary(json_file)
    headers = {
      :to        =>  RECIPIENTS,
      :subject   =>  "Inconsistent data exists among global,non global pods",
      :sent_on   => Time.now,
      :body      => "The details of accounts that are inconsistent are present in the attachment."
    }
    attachments.inline['inconsistent_accounts.csv'] = {
      mime_type: 'application/csv; charset=utf-8; header=present',
      content: JSON.pretty_generate(json_file)
    }
    mail(headers).deliver
  end

end
