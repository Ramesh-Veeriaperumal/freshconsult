class Helpdesk::TicketFields::UpdateTicketFilter < BaseWorker
  include Dashboard::Custom::CacheKeys
  include Cache::Memcache::Dashboard::Custom::CacheData

  sidekiq_options :queue => :update_ticket_filter, :retry => 1, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    account     = Account.current
    conditions  = args[:conditions]
    field_id = args[:field_id]

    account.ticket_filters.each do |filter|
      updated = false
      conditions.each { |condition|
        condition.symbolize_keys!
        replace_key   = condition[:replace_key]
        condition_key = condition[:condition_key]

        updated = true if filter.update_condition(condition_key, replace_key)
      }
      filter.save if updated
    end

    # Gets all dashboards with bar chart widgets to mark the ticket field deleted state
    account.dashboards.joins(:widgets).where('dashboard_widgets.widget_type = 1').group(:dashboard_id).each do |dashboard|
      dirty = false
      dashboard.widgets.each do |widget|
        next unless widget.config_data[:categorised_by] == field_id
        widget.active = false
        widget.save
        dirty = true
        Rails.logger.info("Updated dashboard :: #{dashboard.id} :: #{widget.id}")
      end
      clear_dashboards_cache(dashboard) if dirty
    end
  rescue Exception => e
    Rails.logger.info("Error in UpdateTicketFilter worker :: #{args.inspect} :: #{e.message} :: #{e.backtrace}")
    puts e.inspect, args.inspect
    NewRelic::Agent.notice_error(e, {:args => args})
    raise e
  end

  def clear_dashboards_cache(dashboard)
    MemcacheKeys.delete_from_cache(dashboard_cache_key(dashboard.id))
    MemcacheKeys.delete_from_cache(dashboard.bar_chart_key)    
  end
end
