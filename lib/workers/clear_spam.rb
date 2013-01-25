class Workers::ClearSpam
  extend Resque::Plugins::Retry  
  @retry_limit = 3

  @retry_delay = 60*2
  @queue = 'clear_spam_worker'

  def self.perform(account_id)
    begin
      time = 30.days.ago(Time.zone.now).to_s(:db)
      account =  Account.find(account_id)
      account.make_current
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
    Account.reset_current_account 
  end
end