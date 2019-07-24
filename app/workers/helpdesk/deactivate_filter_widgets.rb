class Helpdesk::DeactivateFilterWidgets < BaseWorker
  include Dashboard::Custom::CacheKeys
  include Cache::Memcache::Dashboard::Custom::CacheData

  sidekiq_options queue: :deactivate_filter_widgets, retry: 0,  failures: :exhausted

  def perform(args)
    args.symbolize_keys!
    filter_id = args[:filter_id]

    dashboard_ids = []
    dashboard_widgets ||= Account.current.dashboard_widgets.where('ticket_filter_id = ?', filter_id)
    dashboard_widgets.each do |widget|
      widget.active = false
      widget.save
      dashboard_ids << widget.dashboard_id
    end

    dashboard_ids.each { |dashboard_id| clear_ticket_filter_widgets_from_cache(dashboard_id) }

  rescue Exception => e
    Rails.logger.info("Error in DeactivateFilterWidgets worker :: #{args.inspect} :: #{e.message} :: #{e.backtrace}")
    NewRelic::Agent.notice_error(e, { args: args })
    raise e
  end
end
