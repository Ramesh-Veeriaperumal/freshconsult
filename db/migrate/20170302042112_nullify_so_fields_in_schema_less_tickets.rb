class NullifySoFieldsInSchemaLessTickets < ActiveRecord::Migration
  shard :all

  include Redis::RedisKeys
  include Redis::OthersRedis
  
  SLT_INTERNAL_GROUP_COL = "long_tc03"
  SLT_INTERNAL_AGENT_COL = "long_tc04"

  def self.up
    failed_accounts = []
    failed_tickets = {}
    remove_others_redis_key("SO_FIELDS_MIGRATION") if redis_key_exists?("SO_FIELDS_MIGRATION")
    Account.active_accounts.find_each do |account|
      begin
        account.make_current
        next unless account.features?(:shared_ownership)

        account.schema_less_tickets.where("#{SLT_INTERNAL_GROUP_COL} is not NULL").find_each {|slt|
          begin
            slt.update_column(SLT_INTERNAL_GROUP_COL, nil)
            slt.update_column(SLT_INTERNAL_AGENT_COL, nil)
            slt.ticket.count_es_manual_publish
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
