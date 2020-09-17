class WriteSharedOwnershipFieldsToTicketTable < ActiveRecord::Migration
  include Redis::RedisKeys
  include Redis::OthersRedis
  shard :all
  SLT_INTERNAL_GROUP_COL    = "long_tc03"
  SLT_INTERNAL_AGENT_COL    = "long_tc04"
  TICKET_INTERNAL_GROUP_COL = "internal_group_id"

  def up
    failed_accounts = []
    failed_tickets = {}

    Account.active_accounts.find_each do |account|
      begin
        account.make_current
        next unless account.features?(:shared_ownership)

        account.schema_less_tickets.where("#{SLT_INTERNAL_GROUP_COL} is not NULL").find_in_batches {|slts|
        
          ticket_ids = slts.map(&:ticket_id)
          account.tickets.where(:id => ticket_ids).each {|t|
            begin
              slt = slts.find{|slt| slt.ticket_id == t.id}
              ticket_internal_group_id = t.read_attribute(:internal_group_id)
              ticket_internal_agent_id = t.read_attribute(:internal_agent_id)
              slt_internal_group_id    = slt.read_attribute(SLT_INTERNAL_GROUP_COL)
              slt_internal_agent_id    = slt.read_attribute(SLT_INTERNAL_AGENT_COL)

              if slt_internal_group_id != ticket_internal_group_id || slt_internal_agent_id != ticket_internal_agent_id
                t.update_column(:internal_group_id, slt_internal_group_id) if slt_internal_group_id != ticket_internal_group_id
                t.update_column(:internal_agent_id, slt_internal_agent_id) if slt_internal_agent_id != ticket_internal_agent_id
                t.count_es_manual_publish
              end
            rescue
              failed_tickets[account.id] ||= []
              failed_tickets[account.id] << t.id
            end
          }
          
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

  def down
    failed_accounts = []
    failed_tickets = {}

    Account.active_accounts.find_each do |account|
      begin
        account.make_current
        next unless account.features?(:shared_ownership)
        account.tickets.where("#{TICKET_INTERNAL_GROUP_COL} is not NULL").find_in_batches {|tickets|
        
          ticket_ids = tickets.map(&:id)
          account.schema_less_tickets.where(:ticket_id => ticket_ids).each {|slt|
            begin
              t = tickets.find{|t| t.id == slt.ticket_id}
              ticket_internal_group_id = t.read_attribute(:internal_group_id)
              ticket_internal_agent_id = t.read_attribute(:internal_agent_id)
              slt_internal_group_id    = slt.read_attribute(SLT_INTERNAL_GROUP_COL)
              slt_internal_agent_id    = slt.read_attribute(SLT_INTERNAL_AGENT_COL)

              if ticket_internal_group_id != slt_internal_group_id || internal_agent_id != slt_internal_agent_id
                slt.update_column(SLT_INTERNAL_GROUP_COL, ticket_internal_group_id) if ticket_internal_group_id != slt_internal_group_id
                slt.update_column(SLT_INTERNAL_AGENT_COL, ticket_internal_agent_id) if ticket_internal_agent_id != slt_internal_agent_id
                t.count_es_manual_publish
              end

            rescue
              failed_tickets[account.id] ||= []
              failed_tickets[account.id] << t.id
            end
          }
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

end