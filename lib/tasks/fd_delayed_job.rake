namespace :fd_delayed_job do
  task :clear_501_errors => :environment do
    include ParserUtil
    
    ids_hash = fetch_object_ids
    ids_hash.each do |h|
      begin
        Account.reset_current_account
        account_id = h[:account_id]
        ticket_id  = h[:ticket_id]
        note_id    = h[:note_id]
        Sharding.select_shard_of(account_id) do
          account = Account.find(account_id).make_current
          ticket = account.tickets.find(ticket_id)
          clear_sender_email_error(ticket)
          clear_quotes_and_reply_cc(ticket, note_id)          
        end
      rescue => e
        puts "Exception in clearing 501 syntax :: Message #{e.inspect} :: params #{h.inspect}"
        Account.reset_current_account
      end
    end
    Delayed::Job.where(['last_error like ?', '%501%']).each do |j|
      j.run_at = 1.minutes.from_now
      j.save
    end
  end
  
  def fetch_object_ids
    fjobs = Delayed::Job.where(['last_error like ?', '%501%']).map(&:handler)
    fjobs.inject([]) do |arr, job_handler|
      ticket_id = job_handler.scan(/AR:Helpdesk::Ticket:(\d+)/).flatten.first
      note_id = job_handler.scan(/AR:Helpdesk::Note:(\d+)/).flatten.first
      account_id = job_handler.scan(/AR:Account:(\d+)/).flatten.first
      arr << {:account_id => account_id, :note_id => note_id, :ticket_id => ticket_id }
      arr
    end
  end
  
  def clear_reply_cc(ticket)
    new_reply_cc = []
    ticket.cc_email[:reply_cc].each do |email|
      temp = parse_email email
      next if temp[:email].nil?
      new_reply_cc << email
    end
    new_reply_cc
  end
  
  def clear_sender_email_error(ticket)
    from_email = parse_email ticket.from_email
    if from_email[:email].nil?
      ticket.schema_less_ticket.sender_email = nil
      ticket.schema_less_ticket.save
    end
  end
  
  def clear_quotes_and_reply_cc(ticket, note_id)
    # user_emails =[]
    # ticket.cc_email[:cc_emails].each do |email|
    #   user_emails << email if email.include?('\\')
    # end
    
    # ticket.cc_email[:fwd_emails].each do |email|
    #   user_emails << email if email.include?('\\')
    # end
    
    # ticket.cc_email[:reply_cc].each do |email|
    #   user_emails << email if email.include?('\\')
    # end

    ticket.cc_email[:cc_emails] = ticket.cc_email[:cc_emails].map{ |e| e.gsub('\\', "") } if ticket.cc_email[:cc_emails]
    ticket.cc_email[:fwd_emails] = ticket.cc_email[:fwd_emails].map{ |e| e.gsub('\\', "") } if ticket.cc_email[:fwd_emails]
    ticket.cc_email[:reply_cc] = ticket.cc_email[:reply_cc].map{ |e| e.gsub('\\', "") } if ticket.cc_email[:reply_cc]
    ticket.cc_email[:reply_cc] = clear_reply_cc(ticket)
    ticket.save
    
    if note_id.present?
      sln = ticket.notes.find(note_id).schema_less_note

      # sln.to_emails.each do |email|
      #   user_emails << email if email.include?('\\')
      # end
      # sln.cc_emails.each do |email|
      #   user_emails << email if email.include?('\\')
      # end

      sln.to_emails = sln.to_emails.map{ |e| e.gsub('\\', "") }
      sln.cc_emails = sln.cc_emails.map{ |e| e.gsub('\\', "") }
      sln.save
    end
    
    # user_emails = user_emails.uniq.map { |u| extract_email(u) }
    # users = Account.current.all_users.find_all_by_email(user_emails)
    # users.each do |user|
    #   user.name = user.name.gsub('\\', "")
    #   user.save
    # end
  end
  
end