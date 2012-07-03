SPAM_TICKETS_THRESHOLD = 50 #Allowed number of tickets in 30 minutes window..
SPAM_CONVERSATIONS_THRESHOLD = 50

#We might need to make the time window also as configurable. Right now, 30 minutes looks like a good guess!

namespace :spam_watcher do
  desc 'Check for abnormal activities and email us, if needed'
  task :ticket_load => :environment do
    puts "Check for abnormal activities started at ddddddddddddddddd #{Time.now}"
    check_for_spam('helpdesk_tickets', 'requester_id', SPAM_TICKETS_THRESHOLD)
    check_for_spam('helpdesk_notes', 'user_id', SPAM_CONVERSATIONS_THRESHOLD)
  end
  
  task :unblock => :environment do
    puts "Check for unblock abnormal activities started at #{Time.now}"
    check_for_users_and_unblock
  end
  
end

def check_for_users_and_unblock
  current_time = Time.zone.now #Should it be Time.now?!?!
  query_str = "select id  from users where blocked = 1 and blocked_at < '#{60.minutes.ago(current_time).to_s(:db)}'" 
  users = ActiveRecord::Base.connection.select_values(query_str)
  
  unless users.blank?
    ActiveRecord::Base.connection.execute("update users set blocked = 0,blocked_at = null where id IN (#{users*","}) ")
  end
  
  # query_str = "select id  from users where deleted = 1 and deleted_at < '#{120.minutes.ago(current_time).to_s(:db)}'" 
  # users = ActiveRecord::Base.connection.select_values(query_str)
  
  # unless users.blank?
  #   ActiveRecord::Base.connection.execute("update users set deleted = 0,deleted_at = null where id IN (#{users*","}) ")
  # end

end


def check_for_spam(table,column_name, threshold)
  current_time = Time.zone.now #Should it be Time.now?!?!
  query_str = <<-eos
    select #{column_name},count(*) as total from #{table} where created_at 
    between '#{60.minutes.ago(current_time).to_s(:db)}' and '#{current_time.to_s(:db)}' 
    group by #{column_name} having total > #{threshold}
  eos
  puts query_str
  requesters = ActiveRecord::Base.connection.select_values(query_str)
  puts "The accounts which are having abnormal load in '#{table}' are #{requesters}"
  deliver_spam_alert(table, query_str, {:actual_requesters => requesters}) unless requesters.empty?
  
  # unless requesters.empty?
  #   current_time = Time.zone.now
  #   users = User.find(:all,:conditions => ["id in (?) and user_role in (3,5) and blocked = 0 and whitelisted = 0",requesters])
  #   deleted_users = []
  #   blocked_users = []
  #   users.each do |usr|
  #     if usr.deleted?  
  #       (usr.deleted_at and usr.deleted_at < 60.minutes.ago(current_time)) ? (blocked_users << usr.id) : (deleted_users  << usr.id)
  #     elsif !usr.deleted? 
  #       deleted_users << usr.id
  #     end
  #   end
  #   ActiveRecord::Base.connection.execute("update users set blocked = 1,blocked_at = '#{current_time.to_s(:db)}' where id IN (#{blocked_users*","}) ") unless blocked_users.blank?
  #   ActiveRecord::Base.connection.execute("update users set deleted = 1,deleted_at = '#{current_time.to_s(:db)}' where id IN (#{deleted_users*","}) ") unless deleted_users.blank?
  #   deliver_spam_alert(table, query_str, {:actual_requesters => requesters,:deleted_users => deleted_users,:blocked_users => blocked_users}) unless requesters.empty?
  # end

  
end

def deliver_spam_alert(table, query_str,additional_info)
  FreshdeskErrorsMailer.deliver_error_email(nil, nil, nil,
    {
      :subject          => "Abnormal load by spam watcher #{table}",
      :additional_info  => {
        :actual_requesters  => additional_info[:actual_requesters].inspect,
        #:deleted_users  => additional_info[:deleted_users].inspect,
        #:blocked_users  => additional_info[:blocked_users].inspect,
        :query          => query_str
      }
    }
  )
end
