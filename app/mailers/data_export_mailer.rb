class DataExportMailer < ActionMailer::Base
	
  layout "email_font"
  
  def data_backup(options={})
    headers = {
      :to    => options[:email],
      :from  => AppConfig['from_email'],
      :subject => "Data Export for #{options[:host]}",
      :sent_on => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    @url = options[:url]
    @account = Account.current
    mail(headers) do | part|
      part.html { render "data_backup", :formats => [:html] }
    end.deliver
  end 

  def ticket_export(options={})
    headers = {
      :subject   => formatted_export_subject(options),
      :to        => options[:user].email,
      :from      => AppConfig['from_email'],
      :bcc       => "reports@freshdesk.com",
      :sent_on   => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
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
      :bcc      => "reports@freshdesk.com",
      :sent_on  => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
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
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply",
      :sent_on   => Time.now
    }
    @user = options[:user]
    @url = options[:url]
    @field = options[:type]
    @account = Account.current
    mail(headers) do |part|
      part.html { render "customer_export", :formats => [:html] }
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
