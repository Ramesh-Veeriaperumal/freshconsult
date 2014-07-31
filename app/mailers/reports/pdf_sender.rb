class  Reports::PdfSender < ActionMailer::Base
  
  def send_report_pdf(subject,body,recipents,pdf,filename)
    headers = {
      :subject   => subject,
      :to        => recipents,
      :from      => AppConfig['from_email'],
      :sent_on   => Time.now
    }
    @body = body.html_safe
    attachments[filename] = {
      :mime_type => 'application/pdf; charset=utf-8; header=present',
      :content   => filename
    }
    mail(headers) do |part|
      part.html { render_nothing }
    end.deliver
  end
  
  # TODO-RAILS3 Can be removed oncewe fully migrate to rails3
  # Keep this include at end
  include MailerDeliverAlias
end
