class  Resque::MyNotifier < ActionMailer::Base
  #include MailQueue
  include Resque::Mailer 
  #puts "hellooooo iam inside@weew@@@@@@@@@@@@@"
  def reply(ticket_id, note_id , reply_email, options={})
    ticket = Helpdesk::Ticket.find(ticket_id)
    note = ticket.notes.find(note_id)
    puts "hellooooo iam inside@@@@@@@@@@@@@@"
    
    subject       ticket.subject
    recipients   ticket.requester.email
    from        reply_email
    body       note.body_html
    sent_on     Time.now
    content_type  "text/html" 
  end  
end
