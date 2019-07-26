class Helpdesk::DeactivateProductWidgets < BaseWorker
  sidekiq_options queue: :deactivate_product_widgets, retry: 0,  failures: :exhausted

  include Cache::Memcache::Dashboard::Custom::CacheData

  def perform(args)
    args.symbolize_keys!
    acc = Account.current

    # Fetching trend card widgets where product filter is used
    product_widgets_dashboards = acc.dashboards.joins(:widgets).where('widget_type IN (5)').includes(:widgets)
    product_widgets_dashboards.each do |dashboard|
      update_product_widgets(dashboard, args[:product_id])
    end
  rescue Exception => e
    Rails.logger.info("Error in DeactivateProductWidgets worker :: #{acc.id} :: #{e.inspect}, #{args.inspect}")
    NewRelic::Agent.notice_error(e, { args: args })
  end

  private

    def update_product_widgets(dashboard, product_id)
      dirty = false
      dashboard.widgets.each do |widget|
        next unless widget.config_data['product_id'] == product_id
        widget.active = false
        widget.config_data['product_id'] = nil
        widget.save
        dirty = true
        Rails.logger.info("Updated widget :: #{Account.current.id} :: #{dashboard.id} :: #{widget.id}")
      end
      clear_product_widgets_from_cache(dashboard.id) if dirty
    end
end
