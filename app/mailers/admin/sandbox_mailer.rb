class Admin::SandboxMailer < ActionMailer::Base
  layout 'email_font'
  include Sync::Constants

  def sandbox_mailer(account, options = {})
    Time.zone = account.time_zone
    headers = {
      :to => options[:recipients],
      :from => AppConfig['from_email'],
      :subject => options[:subject],
      :sent_on => Time.now,
      'Reply-to' => '',
      'Auto-Submitted' => 'auto-generated',
      'X-Auto-Response-Suppress' => 'DR, RN, OOF, AutoReply'
    }
    @additional_info = options[:additional_info]
    @logo = LOGO_MAP
    mail(headers) do |part|
      part.html { render options[:notifier] }
    end.deliver
  end
end
