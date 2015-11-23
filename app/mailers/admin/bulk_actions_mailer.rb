class Admin::BulkActionsMailer < ActionMailer::Base

  layout "email_font"
  
  def bulk_actions_email(options={})
    options.symbolize_keys!
    @redis_info = options
    headers = {
      # :to      => options[:email],
      :to      => 'reports@freshdesk.com',
      :from    => AppConfig['from_email'],
      :subject => "Bulk Admin Action for #{options[:domain_name]}",
      :sent_on => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    mail(headers) do |part|
      part.html { render "bulk_actions_email", :formats => [:html] }
    end.deliver
  end 

  # TODO-RAILS3 Can be removed once fully migrate to rails3
  # Keep this include at end
  include MailerDeliverAlias
end