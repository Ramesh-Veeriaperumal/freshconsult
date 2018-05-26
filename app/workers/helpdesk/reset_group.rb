class Helpdesk::ResetGroup < BaseWorker
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Dashboard::Custom::CacheKeys
  include Redis::HashMethods

  sidekiq_options queue: :reset_group, retry: 0, backtrace: true, failures: :exhausted
  BATCH_LIMIT = 50

  def perform(args)
    args.symbolize_keys!
    account   = Account.current
    group_id  = args[:group_id]
    reason    = args[:reason].symbolize_keys!
    options   = { reason: reason, manual_publish: true }

    handle_dashboards_widgets(group_id)

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
    Rails.logger.info "Error in ResetGroup worker :: #{e.inspect}, #{args.inspect}"
    NewRelic::Agent.notice_error(e, { args: args })
  end

  def handle_dashboards_widgets(group_id)
    Rails.logger.info "In ResetGroup worker:: Handling dashboards"
    account_dashboards = multi_get_all_redis_hash(dashboard_index_redis_key)
    account_dashboards.each do |id, dashboard_object|
      parsed_dashboard_object = JSON.parse(dashboard_object)
      update_dashboard_access(id, group_id, parsed_dashboard_object['group_ids'].length) if parsed_dashboard_object['group_ids'] && parsed_dashboard_object['group_ids'].include?(group_id)
    end
    update_widgets(group_id)
  end

  def update_dashboard_access(dashboard_id, group_id, groups_len)
    Rails.logger.info "In ResetGroup worker:: Handling dashboard :: #{dashboard_id}"
    dashboard = Account.current.dashboards.find(dashboard_id)
    if dashboard
      dashboard.accessible.remove_group_accesses([group_id])
      dashboard.update_attributes(accessible_attributes: { access_type: 0 }) unless groups_len > 1 # updating access type to all agents if group_id is the only group
    end
  end

  def update_widgets(group_id)
    group_widgets_dashboards = Account.current.dashboards.joins(:widgets).where('widget_type IN (2,3,5)').includes(:widgets)
    group_widgets_dashboards.each do |dashboard|
      update_group_widgets(dashboard, group_id)
    end
  end

  def update_group_widgets(dashboard, group_id)
    dirty = false
    dashboard.widgets.each do |widget|
      config = widget.config_data
      if (config['group_ids'] && config['group_ids'].include?(group_id)) || config['group_id'] == group_id
        widget.active = false
        dirty = true
      end
    end
    Rails.logger.info "In ResetGroup worker:: Handling dashboard widgets:: #{dashboard.id} :: #{dirty}"
    MemcacheKeys.delete_from_cache(dashboard_cache_key(dashboard.id)) if dirty
  end
end
