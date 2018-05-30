class Admin::SandboxMailer < ActionMailer::Base
  layout "email_font"

  def sandbox_ready(account, options={})
    Time.zone = account.time_zone
    headers = {
        :to    => options[:recipients] || account.notification_emails,
        :from  => AppConfig['from_email'],
        :subject => I18n.t('sandbox.live'),
        :sent_on => Time.now,
        "Reply-to" => "",
        "Auto-Submitted" => "auto-generated",
        "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    @additional_info = options[:additional_info]
    mail(headers) do |part|
      part.html { render "notifier" }
    end.deliver
  end
end

