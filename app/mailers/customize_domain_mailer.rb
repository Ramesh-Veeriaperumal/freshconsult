class CustomizeDomainMailer < ActionMailer::Base

  layout "email_font"

   def domain_changed(options={})
    headers = {
      :to        => options[:to_email],
      :from      => "support@freshdesk.com",
      :subject   => I18n.t('customize_domain.email.subject', :account_name => options[:account_name]),
      :sent_on   => Time.now
    }
    @name = options[:name]
    @url = options[:url]
    @is_agent = options[:is_agent]
    @account_name = options[:account_name]
    mail(headers) do |part|
      part.html { render "customize_domain", :formats => [:html] }
    end.deliver
  end
end