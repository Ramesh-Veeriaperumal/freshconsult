class DataExportMailer < ActionMailer::Base
	
  layout "email_font"
  include EmailHelper
  
  def data_backup(options={})
    headers = {
      :to    => options[:email],
      :from  => AppConfig['from_email'],
      :bcc   => AppConfig['reports_email'],
      :subject => "Data Export for #{options[:host]}",
      :sent_on => Time.now,
      "Reply-to" => ""
    }
    @url = options[:url]
    @account = Account.current
    headers.merge!(make_header(nil, nil, @account.id, "Data Backup"))
    mail(headers) do | part|
      part.html { render "data_backup", :formats => [:html] }
    end.deliver
  end 

  def ticket_export(options={})
    headers = {
      :subject   => formatted_export_subject(options),
      :to        => options[:user].email,
      :from      => AppConfig['from_email'],
      :bcc       => AppConfig['reports_email'],
      :sent_on   => Time.now,
      "Reply-to" => ""
    }

    headers.merge!(make_header(nil, nil, options[:user].account_id, "Ticket Export"))
    @user = options[:user]
    @url  = options[:url]
    @account = @user.account
    mail(headers) do |part|
      part.html { render "ticket_export", :formats => [:html] }
    end.deliver
  end

  def no_tickets(options={})
    headers = {
      :subject  => "No tickets in range - #{options[:domain]}",
      :to       => options[:user][:email],
      :from     => AppConfig['from_email'],
      :bcc      => AppConfig['reports_email'],
      :sent_on  => Time.now,
      "Reply-to" => ""
    }

    headers.merge!(make_header(nil, nil, options[:user].account_id, "No Tickets"))
    @user = options[:user]
    @account = @user.account
    mail(headers) do |part|
      part.html { render "no_tickets", :formats => [:html] }
    end.deliver
  end

  def customer_export(options={})
    headers = {
      :subject => "#{options[:type].capitalize} export for #{options[:domain]}",
      :to      => options[:user].email,
      :from    => "support@freshdesk.com",
      :bcc     => AppConfig['reports_email'],
      "Reply-to" => "",
      :sent_on   => Time.now
    }

    headers.merge!(make_header(nil, nil, options[:user].account_id, "Customer Export"))
    @user = options[:user]
    @url = options[:url]
    @field = options[:type]
    @account = Account.current
    mail(headers) do |part|
      part.html { render "customer_export", :formats => [:html] }
    end.deliver
  end
  
  def reports_export options={}
    headers = {
      :subject => "Reports Export for #{options[:range]}",
      :to      => options[:user].email,
      :from    => AppConfig['from_email'],
      :bcc      => AppConfig['reports_email'],
      "Reply-to" => "",
      :sent_on   => Time.now
    }

    headers.merge!(make_header(nil, nil, options[:user].account_id, "Reports Export"))
    @user      = options[:user]
    @export_url = options[:export_url]
    mail(headers) do |part|
      part.html { render "reports_export", :formats => [:html] }
    end.deliver
  end

  def agent_export options={}
    headers = {
      :subject => "Agents List Export",
      :to      => options[:user].email,
      :from    => AppConfig['from_email'],
      :bcc     => AppConfig['reports_email'],
      :sent_on   => Time.now
    }

    headers.merge!(make_header(nil, nil, options[:user].account_id, "Agent Export"))
    @user = options[:user]
    @url = options[:url]
    mail(headers) do |part|
      part.html { render "agent_export", :formats => [:html] }
    end.deliver
  end
 
  def broadcast_message options={}
    message_id = "#{Mail.random_tag}.#{::Socket.gethostname}@private-notification.freshdesk.com"
    headers = {
      "Message-ID"                =>  "<#{message_id}>",
      "Auto-Submitted"            =>  "auto-generated",
      "X-Auto-Response-Suppress"  =>  "DR, RN, OOF, AutoReply",
      :subject                    => options[:subject],
      :to                         => options[:to_email],
      :from                       => options[:from_email],
      :sent_on                    => Time.now
    }

    headers.merge!(make_header(options[:ticket_id], nil, options[:account_id], "Broadcast Message"))
    @url = options[:url]
    @subject = options[:ticket_subject]
    @content = options[:content]
    mail(headers) do |part|
      part.html { render "broadcast_message", :formats => [:html] }
    end.deliver
  end

  private
    def formatted_export_subject(options)
      filter = I18n.t("export_data.#{options[:export_params][:ticket_state_filter]}")
      I18n.t('export_data.ticket_export.subject',
            :filter => filter,
            :start_date => options[:export_params][:start_date].to_date, 
            :end_date => options[:export_params][:end_date].to_date,
            :domain => options[:domain])
    end

  # TODO-RAILS3 Can be removed oncewe fully migrate to rails3
  # Keep this include at end
  include MailerDeliverAlias
end
