class DataExportFailureMailer < ActionMailer::Base
  layout "email_font"
  include EmailHelper
  def data_backup_failure(options={})
    headers = {
        :to    => options[:email],
        :from  => AppConfig['from_email'],
        :bcc   => AppConfig['reports_email'],
        :subject => "Data Export for #{options[:host]}",
        :sent_on => Time.now,
        "Reply-to" => ""
    }
    @account = Account.current
    headers.merge!(make_header(nil, nil, @account.id, "Data Backup"))
      mail(headers) do | part|
        part.html { render "data_backup_failure", :formats => [:html] }
      end.deliver
  end
end
