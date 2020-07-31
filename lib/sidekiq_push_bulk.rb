module SidekiqPushBulk
  # This method can be used to push bulk jobs to sidekiq, This will save some redis round trip time
  # on pusing bunch jobs to sidekiq queue. Example: If you are doing perform_async for a 1000 jobs
  # that will make 1000 redis calls, But here only one redis call would be made. You can save 999 calls
  #
  # NOTE: items: Should be Array of Arrays (or) you can pass a block, see the below examples
  #
  # Usage:
  # => push_bulk_jobs('Archive::TicketWorker', [[{ ticket_id: 1 }], [{ ticket_id: 2 }], [{ ticket_id: 3 }]], 300)
  #                                    (OR)
  # => push_bulk_jobs('Archive::TicketWorker', Account.current.tickets, 300 ) do |ticket|
  #      _ticket_id = ticket.display_id
  #      _archive_days = Account.current.account_additional_settings.archive_days
  #      [ { ticket_id: _ticket_id, archive_days: _archive_days } ]
  #    end
  def push_bulk_jobs(worker_class, items, limit: 1_000, &block)
    @worker_klass = worker_class.constantize
    # Sidekiq recommends to have a limit of 1000 per batch eventhough the max limit is 10_000
    # https://github.com/mperham/sidekiq/blob/df2665b30a3139037f0a21ea7475ea1ef3d1fd03/lib/sidekiq/client.rb#L81
    job_ids = items.each_slice(limit).map do |group_of_items|
      build_args_and_push(group_of_items, &block)
    end
    job_ids.flatten
  end

  private

    def build_args_and_push(items, &block)
      sidekiq_bulk_args = {
        class: @worker_klass,
        args: block.present? ? items.map(&block) : items
      }.with_indifferent_access
      Sidekiq::Client.push_bulk(sidekiq_bulk_args)
    end
end
