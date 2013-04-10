class Workers::ClearSpam
  extend Resque::AroundPerform  

  @queue = 'clear_spam_worker'

  def self.perform
      time = 30.days.ago(Time.zone.now).to_s(:db)
      account =  Account.current
      conditions =  ["(deleted = ? OR blocked = ?) and deleted_at < ? 
        and whitelisted = false AND account_id = ?", true, true, time, account.id]
      User.with_conditions(conditions).find_in_batches do |batches|
        batches.each do |user|
          Helpdesk::Ticket.spam_created_in(user).find_in_batches do |ticket_batches|
            ticket_batches.each do |ticket|
              ticket.destroy
            end
          end
        end
        $redis.srem("SPAM_CLEARABLE_ACCOUNTS",account.id)
      end
    rescue Exception => e
      puts "something is wrong: #{e.message}::#{e.backtrace.join("\n")}"
    rescue
      puts "something went wrong"
  end

end