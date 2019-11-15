class Helpdesk::ResetArchiveTickets < BaseWorker
  include Redis::RedisKeys
  include Redis::OthersRedis
  include BulkOperationsHelper

  sidekiq_options queue: :reset_archive_tickets, retry: 1, failures: :exhausted

  def perform(args)
    args.symbolize_keys!
    @account = Account.current
    @group_id = args[:group_id]
    @user_id = args[:user_id]
    @rate_limit_options = { rate_limit: rate_limit_options(args) }

    return unless @account.features_included?(:archive_tickets)

    if @group_id
      reset_group_id
    elsif @user_id
      reset_responser_id
    end
  rescue Exception => e
    NewRelic::Agent.notice_error(e, args: args)
    raise e
  end

  private

    def reset_group_id
      archive_tickets = @account.archive_tickets.where(group_id: @group_id)
      archive_tickets.update_all_with_publish({ group_id: nil }, {}, @rate_limit_options)
    end

    def reset_responser_id
      archive_tickets = @account.archive_tickets.where(responder_id: @user_id)
      archive_tickets.update_all_with_publish({ responder_id: nil }, {}, @rate_limit_options)
    end
end
