class Helpdesk::ResetGroup < BaseWorker

  include Redis::RedisKeys
  include Redis::OthersRedis
  include BulkOperationsHelper

  sidekiq_options :queue => :reset_group, :retry => 0, :backtrace => true, :failures => :exhausted
  BATCH_LIMIT = 50

  def perform(args)
    begin
      args.symbolize_keys!
      account   = Account.current
      group_id  = args[:group_id]
      reason    = args[:reason].symbolize_keys!
      options   = { reason: reason, manual_publish: true, rate_limit: rate_limit_options(args) }

      account.tickets.where(group_id: group_id).update_all_with_publish({ group_id: nil }, {}, options)

      if account.shared_ownership_enabled?
        #  Changed reason hash for shared ownership
        reason[:delete_internal_group]  = reason.delete(:delete_group)
        options                         = {:reason => reason, :manual_publish => true}
        updates_hash                    = {:internal_group_id => nil, :internal_agent_id => nil}

        tickets = nil
        Sharding.run_on_slave do
          tickets = account.tickets.where(:internal_group_id => group_id)
        end
        tickets.update_all_with_publish(updates_hash, {}, options)
      end

      return unless account.features_included?(:archive_tickets)

      account.archive_tickets.where(group_id: group_id).update_all_with_publish({ group_id: nil }, {})

    rescue Exception => e
      puts e.inspect, args.inspect
      NewRelic::Agent.notice_error(e, {:args => args})
    end
  end

end
