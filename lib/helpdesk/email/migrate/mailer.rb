module Helpdesk::Email::Migrate
  class Mailer < ActionMailer::Base
    def send_mail(notify_email,text="")
      headers = {:subject =>       "Mail from console",
                  :to =>            notify_email,
                  :from =>          AppConfig['from_email'],
                  :sent_on =>       Time.now,
                  :content_type =>  "text/html",
                  :body =>           text}
      mail(headers).deliver
    end
  end
end