class  Reports::PdfSender < ActionMailer::Base
  
  def send_report_pdf(subject,body,recipents,pdf,filename)
    subject       subject
    recipients    recipents
    body          body
    from          AppConfig['from_email']
    sent_on       Time.now
    content_type  "multipart/mixed"

    attachment    :content_type => 'application/pdf; charset=utf-8; header=present', 
                  :body => pdf, 
                  :filename => filename

    content_type  "text/html"
  end
  
end
