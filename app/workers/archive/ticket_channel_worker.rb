module Archive
  class TicketChannelWorker < Archive::TicketWorker
    sidekiq_options queue: :archive_tickets_channel_queue, retry: 0, backtrace: true, failures: :exhausted
  end
end
