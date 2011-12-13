SPAM_TICKETS_THRESHOLD = 20 #Allowed number of tickets in 30 minutes window..
SPAM_CONVERSATIONS_THRESHOLD = 20
#We might need to make the time window also as configurable. Right now, 30 minutes looks like a good guess!

namespace :spam_watcher do
  desc 'Check for abnormal activities and email us, if needed'
  task :ticket_load => :environment do
    puts "Check for abnormal activities started at ddddddddddddddddd #{Time.now}"
    check_tickets('helpdesk_tickets', 'requester_id', SPAM_TICKETS_THRESHOLD)
    check_tickets('helpdesk_notes', 'user_id', SPAM_CONVERSATIONS_THRESHOLD)
  end
  
  task :unblock => :environment do
    puts "Check for unblock abnormal activities started at #{Time.now}"
    check_for_users_and_unblock
  end
  
end

def check_for_users_and_unblock
  current_time = Time.now #Should it be Time.now?!?!
  query_str = "select id  from users where blocked_at < '#{60.minutes.ago(current_time).to_s(:db)}'" 
  users = ActiveRecord::Base.connection.select_values(query_str)
  
  unless users.blank?
    puts "update users set blocked = 0,blocked_at = null where id IN (#{users*","}) "
    ActiveRecord::Base.connection.execute("update users set blocked = 0,blocked_at = null where id IN (#{users*","}) ")
  end
  
end

def check_tickets(table,column_name, threshold)
  current_time = Time.now #Should it be Time.now?!?!
  query_str = <<-eos
    select #{column_name},count(*) as total from #{table} where created_at 
    between '#{10.minutes.ago(current_time).to_s(:db)}' and '#{current_time.to_s(:db)}' 
    group by #{column_name} having total > #{threshold}
  eos
  puts query_str
  requesters = ActiveRecord::Base.connection.select_values(query_str)
  puts "The accounts which are having abnormal load in '#{table}' are #{requesters}"
  
  unless requesters.empty?
    deliver_spam_alert(table, requesters, query_str) 
    requesters.each do |requester_id|
      usr = User.find(requester_id)
#      unless usr.blocked?
#        usr.blocked = true
#        usr.blocked_at = current_time.to_s(:db)
#        usr.save
#      end
    end
  end

  
end

def deliver_spam_alert(table, requesters, query_str)
  FreshdeskErrorsMailer.deliver_error_email(nil, nil, nil,
    {
      :subject          => "Abnormal load in #{table}",
      :additional_info  => {
        :accounts_list  => requesters,
        :query          => query_str
      }
    }
  )
end
