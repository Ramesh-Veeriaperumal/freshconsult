class ScheduledTaskMailer < ActionMailer::Base
  
  def expired_task task
    required_params task
    headers = mail_headers

    mail(headers) do |part|
      part.text { render "expired_task.plain" }
      part.html { render "expired_task.html" }
    end.deliver
  end
  
  def notify_blocked_or_deleted task, options
    @to_emails = task.user.email
    headers = mail_headers({subject: "[Important] Scheduled Report - Recipient Update Required"})

    @task = task
    @user = task.user
    @options = options

    mail(headers) do |part|
      part.text { render "blocked_user_or_email.plain" }
      part.html { render "blocked_user_or_email.html" }
    end.deliver
  end
  
  def notify_downgraded_user task, options
    @to_emails = task.user.email
    headers = mail_headers({subject: "[Important] Scheduled Report - Recipient Update Required"})
    
    @task = task
    @user = task.user
    @options = options

    mail(headers) do |part|
      part.text { render "notify_downgraded_user.plain" }
      part.html { render "notify_downgraded_user.html" }
    end.deliver
  end
  
  def email_scheduled_report options, task
    required_params task

    if @to_emails.present?
      headers = mail_headers
      
      if options[:file_path].present?
        attachment_name = get_attachment_file_name(options[:file_path])
        attachments[attachment_name] = File.read(options[:file_path])
      else
        @export_url = options[:export_url]
      end
      
      mail(headers) do |part|
        part.text { render "email_scheduled_report.plain" }
        part.html { render "email_scheduled_report.html" }
      end.deliver
    end

  end
  
  def report_no_data_email options, task
    required_params task
    headers = mail_headers

    mail(headers) do |part|
      part.text { render "report_no_data_email.plain" }
      part.html { render "report_no_data_email.html" }
    end.deliver
  end
  
  def required_params task
    @task = task
    @config = @task.schedule_configurations.with_notification_type(:email_notification).first
    @user = task.user
    @to_emails = to_emails
  end
  
private

  def mail_headers options = {}
    {
      :subject     => options[:subject] || mail_subject,
      :to          => @to_emails,
      :from        => AppConfig['from_email'],
      "Reply-to"   => "",
      :sent_on     => Time.now,
      "Auto-Submitted" => "auto-generated",
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
  end
  
  def mail_subject
    @config.config_data[:subject]
  end
  
  def to_emails
    emails_and_users = @config.config_data[:emails]
    agent_status = @config.config_data[:agents_status] || []
    emails = check_user_and_email_status(emails_and_users, agent_status)
  
    ScheduledTaskMailer.notify_blocked_or_deleted(@task, emails) if(emails[:blocked_emails].present?)
    ScheduledTaskMailer.notify_downgraded_user(@task, emails) if(emails[:agent_downgraded].present?)
    
    emails[:to_emails]
  end
  
  def check_user_and_email_status(emails_and_users, agent_status)
    result = {to_emails: [], blocked_emails: [], agent_downgraded: []}
    users = pre_load_user_with_emails(emails_and_users.values.uniq)

    emails_and_users.each do |email, user_id|
      user = users[user_id.to_i]
      if (user.deleted? || user.blocked?)
        result[:blocked_emails] << email
      elsif (user.emails.include?(email))
        result[:to_emails] << email
      else
        result[:blocked_emails] << email
      end
      
      result[:agent_downgraded] << user if agent_status.include?(user_id) && !user.helpdesk_agent?
    end
    result
  end
  
  def pre_load_user_with_emails ids
    Sharding.select_shard_of(Account.current.id) do
      Sharding.run_on_slave do
        Account.current.all_users.find_all_by_id(ids, 
                                :select => "id, email, blocked, deleted, helpdesk_agent", 
                                :include => :user_emails).collect{|u| [u.id, u]}.to_h
      end
    end
  end
  
  def check_user_email user, email
    user.emails.include?(email) ? email : nil
  end
  
  private
  def get_attachment_file_name file_path
    file_name_arr = file_path.split("/").last.split(/[-.]/)
    format = file_name_arr.pop
    file_name_arr.pop #removing secure random code
    file_name = file_name_arr.first.gsub(/_+/,"_").slice(0,235)
    "#{file_name}-#{file_name_arr[1..-1].join("-")}.#{format}"
  end
end