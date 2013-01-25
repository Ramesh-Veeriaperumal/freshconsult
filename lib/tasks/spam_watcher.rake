SPAM_TICKETS_THRESHOLD = 50 #Allowed number of tickets in 30 minutes window..
SPAM_CONVERSATIONS_THRESHOLD = 50
TICKETS_ID_LIMIT = 5961998
NOTES_ID_LIMIT = 5891917
# TICKETS_ID_LIMIT = 1
# NOTES_ID_LIMIT = 1
DB_SLAVE = "slave"

#We might need to make the time window also as configurable. Right now, 30 minutes looks like a good guess!

namespace :spam_watcher do
  desc 'Check for abnormal activities and email us, if needed'
  task :ticket_load => :environment do
    puts "Check for abnormal activities started at  #{Time.now}"
    check_for_slave_db unless Rails.env.development?
    check_for_spam('helpdesk_tickets', 'requester_id', TICKETS_ID_LIMIT, SPAM_TICKETS_THRESHOLD)
    check_for_spam('helpdesk_notes', 'user_id', NOTES_ID_LIMIT, SPAM_CONVERSATIONS_THRESHOLD)
    puts "Check for abnormal activities end at  #{Time.now}"
  end
  
  task :unblock => :environment do
    puts "Check for unblock abnormal activities started at #{Time.now}"
    check_for_users_and_unblock
  end

  task :clear_spam_tickets => :environment do
    account_ids = $redis.smembers("SPAM_CLEARABLE_ACCOUNTS")
    return unless account_ids
    accounts = Account.active_accounts.find(:all,:conditions => ["accounts.id in (?)",account_ids])
    accounts.each { |account| Resque.enqueue( Workers::ClearSpam, account.id) }
  end
  
end

def check_for_slave_db
 @db_to_connect = Rails.configuration.database_configuration.keys.include?(DB_SLAVE) ? DB_SLAVE :  Rails.env
end

def execute_sql_on_slave(query_str)
  ActiveRecord::Base.establish_connection(@db_to_connect).connection.select_all(query_str)
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

def check_for_spam(table,column_name, id_limit, threshold)
  current_time = Time.zone.now #Should it be Time.now?!?!
  query_str = <<-eos
    select #{column_name},count(*) as total, account_id from #{table} where created_at 
    between '#{60.minutes.ago(current_time).to_s(:db)}' and '#{current_time.to_s(:db)}' and #{column_name} IS NOT NULL
    and id > #{id_limit} group by #{column_name} having total > #{threshold}
  eos
  puts query_str
  results = execute_sql_on_slave(query_str)
  return if results.blank?
  puts ":::::::::->#{results.inspect}"
  user_ids = []
  account_ids = []
  results.each{ |x| user_ids << x[column_name]; account_ids << x['account_id'] }
  
  user_sql = <<-eos
    select id,deleted,deleted_at from users where user_role in (#{User::USER_ROLES_KEYS_BY_TOKEN[:customer]}, #{User::USER_ROLES_KEYS_BY_TOKEN[:client_manager]})
    and blocked = 0 and whitelisted = 0 and id in (#{user_ids*","})
  eos
  puts user_sql
  users = execute_sql_on_slave(user_sql)
  deleted_users = []
  blocked_users = []
  puts "::::::::#{users.inspect}"
  users.each do |usr|
    blocked_users << usr["id"] if "1".eql?(usr["deleted"]) and (usr["deleted_at"] and Time.zone.parse(usr["deleted_at"]) < 60.minutes.ago(current_time))
    deleted_users << usr["id"] unless "1".eql?(usr["deleted"])
  end
  puts "deleted_users::::#{deleted_users.inspect}::::#{deleted_users.blank?}"
  ActiveRecord::Base.connection.execute("update users set blocked = 1,blocked_at = '#{current_time.to_s(:db)}', deleted=0 where id IN (#{blocked_users*","}) ") unless blocked_users.blank?
  ActiveRecord::Base.connection.execute("update users set deleted = 1,deleted_at = '#{current_time.to_s(:db)}' where id IN (#{deleted_users*","}) ") unless deleted_users.blank?
  deliver_spam_alert(table, query_str, {:actual_requesters => user_ids, 
    :deleted_users => deleted_users, :blocked_users => blocked_users}) unless user_ids.empty?

  accounts = Account.find(:all,:conditions => ["accounts.id in (?)",account_ids])
  accounts.each do |account|
    puts "::::account->#{account}"
    $redis.sadd("SPAM_CLEARABLE_ACCOUNTS",account.id)
    unless deleted_users.empty?
      deleted_users = account.all_users.find(user_ids)
      SubscriptionNotifier.send_later(:deliver_account_admin_spam_watcher, account.account_admin, deleted_users)
    end
  end
end


def check_for_tickets_spam(table,column_name, threshold)
  current_time = Time.zone.now #Should it be Time.now?!?!
  query_str = <<-eos
    select #{column_name},count(*) as total from #{table} where created_at 
    between '#{60.minutes.ago(current_time).to_s(:db)}' and '#{current_time.to_s(:db)}'  and id > 5961998
    group by #{column_name} having total > #{threshold}
  eos
  requesters = execute_sql_on_slave(query_str)
  puts query_str
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

def check_for_notes_spam(table,column_name, threshold)
  current_time = Time.zone.now #Should it be Time.now?!?!
  query_str = <<-eos
    select #{column_name},count(*) as total from #{table} where created_at 
    between '#{60.minutes.ago(current_time).to_s(:db)}' and '#{current_time.to_s(:db)}' and id > 4891917
    group by #{column_name} having total > #{threshold}
  eos
  requesters = execute_sql_on_slave(query_str)
  puts query_str
  deliver_spam_alert(table, query_str, {:actual_requesters => requesters}) unless requesters.empty?
end

def deliver_spam_alert(table, query_str,additional_info)
  FreshdeskErrorsMailer.deliver_error_email(nil, nil, nil,
    {
      :subject          => "Abnormal load by spam watcher #{table}",
      :additional_info  => {
        :actual_requesters  => additional_info[:actual_requesters].inspect,
        :deleted_users  => additional_info[:deleted_users].inspect,
        :blocked_users  => additional_info[:blocked_users].inspect
      },
      :query => query_str
    }
  )
end
