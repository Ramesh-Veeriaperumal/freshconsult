class DataExportMailer < ActionMailer::Base
	
  layout "email_font"
  
  def data_backup(options={}) 
    recipients    options[:email]
    from          "support@freshdesk.com"
    subject       "Data Export for #{options[:host]}"
    bcc           "reports@freshdesk.com"
    headers       "Reply-to" => "","Auto-Submitted" => "auto-generated", "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    sent_on       Time.now
    body(:url => options[:url], :account => Account.current)
    content_type  "text/html"
  end 

  def ticket_export(options={})
    subject       formatted_export_subject(options)
    recipients    options[:user].email
    body          :user => options[:user], :url => options[:url], :account => Account.current
    from          "support@freshdesk.com"
    headers       "Reply-to" => "","Auto-Submitted" => "auto-generated", "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    #bcc - Temporary fix for reports. Need to remove when ticket export is fully done.
    bcc           "reports@freshdesk.com"
    sent_on       Time.now
    content_type  "text/html"
  end

  def no_tickets(options={})
    subject       "No tickets in range - #{options[:domain]}"
    recipients    options[:user][:email]
    body          :user => options[:user], :account => Account.current
    from          "support@freshdesk.com"
    headers       "Reply-to" => "","Auto-Submitted" => "auto-generated", "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    #bcc - Temporary fix for reports. Need to remove when ticket export is fully done.
    bcc           "reports@freshdesk.com"
    sent_on       Time.now
    content_type  "text/html"
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

end
