class FreshopsMailer < ActionMailer::Base
  default from: "admin@freshdesk.com"
  RECIPIENTS = "dev-ops@freshdesk.com"
  CORE_ALIAS = "freshdesk-core-dev@freshdesk.com"

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

  def send_redis_slowlog(csv)
    headers = {
      :to       => CORE_ALIAS,
      :cc       => RECIPIENTS,
      :subject  => "Redis Slowlog for last week",
      :sent_on  => Time.now,
      :body     => "Please find Redis Slowlog Queries for #{PodConfig['CURRENT_POD'].capitalize}"
    }

    attachments.inline['redis_slowlog.csv'] = {
      mime_type: 'application/csv; charset=utf-8; header=present',
      content: csv
    }
    mail(headers).deliver
  end

  def send_daypass_usage_export(to_email, csv)
    headers = {
      to:  to_email,
      cc:  "ramkumar@freshworks.com",
      subject:  "Daypass Usage Report",
      sent_on:  Time.now,
      body:  "Please find Daypass Usage Report"
    }

    attachments.inline['day_pass_usage.csv'] = {
      mime_type: 'application/csv; charset=utf-8; header=present',
      content: csv
    }
    mail(headers).deliver
  end
end
