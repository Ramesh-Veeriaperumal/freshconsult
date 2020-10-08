class PublishSharedOwnershipDataToEs < ActiveRecord::Migration
  shard :all
  
  def migrate(direction)
    self.send(direction)
  end

  def up
    failed_accounts = []
    failed_tickets = {}
    Account.active_accounts.find_each do |account|
      begin
        account.make_current
        next unless account.shared_ownership_enabled?

        account.tickets.where("internal_group_id is not NULL or internal_agent_id is not NULL").find_each {|t|
          begin
            t.sqs_manual_publish
          rescue
            failed_tickets[account.id] ||= []
            failed_tickets[account.id] << t.id
          end
        }
      rescue
        failed_accounts << account.id
      ensure
        Account.reset_current_account
      end
    end

    puts "failed_accounts = #{failed_accounts.inspect}"
    puts "failed_tickets = #{failed_tickets.inspect}"
  end

  def self.down

  end

end
