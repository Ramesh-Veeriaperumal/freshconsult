class Helpdesk::ResetGroup < BaseWorker
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Cache::Memcache::Dashboard::Custom::CacheData
  include Redis::HashMethods
  include Dashboard::Custom::CacheKeys

  sidekiq_options queue: :reset_group, retry: 0,  failures: :exhausted
  BATCH_LIMIT = 50
  # 2 - csat 3 - leaderboard 5 - ticket_trend_card 6 - time_trend_card 7 - sla_trend_card
  DASHBOARD_GROUP_WIDGETS = [2, 3, 5, 6, 7].freeze

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
      options                         = { :reason => reason, :manual_publish => true }
      updates_hash                    = { :internal_group_id => nil, :internal_agent_id => nil }

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

  private

    def handle_dashboards_widgets(group_id)
      Rails.logger.info 'In ResetGroup worker:: Handling dashboards'
      account_dashboards = multi_get_all_redis_hash(dashboard_index_redis_key)
      account_dashboards.each do |id, dashboard_object|
        parsed_dashboard_object = JSON.parse(dashboard_object)
        update_dashboard_access(id) if parsed_dashboard_object['group_ids'] && parsed_dashboard_object['group_ids'].include?(group_id)
      end
      update_widgets(group_id)
    end

    def update_dashboard_access(dashboard_id)
      Rails.logger.info "In ResetGroup worker:: Deleting dashboard :: #{dashboard_id}"
      dashboard = Account.current.dashboards.find(dashboard_id)
      dashboard.destroy if dashboard
    end

    def update_widgets(group_id)
      group_widgets_dashboards = Account.current.dashboards.joins(:widgets).where('widget_type IN (?)', DASHBOARD_GROUP_WIDGETS).includes(:widgets)
      group_widgets_dashboards.each do |dashboard|
        update_group_widgets(dashboard, group_id)
      end
    end

    def update_group_widgets(dashboard, group_id)
      dirty = false
      dashboard.widgets.each do |widget|
        config = widget.config_data
        if (config['group_ids'] && config['group_ids'].include?(group_id)) || config['group_id'] == group_id
          deactivate_widget(widget)
          dirty = true
        end
      end
      Rails.logger.info "In ResetGroup worker:: Handling dashboard widgets:: #{dashboard.id} :: #{dirty}"
      clear_group_widgets_from_cache(dashboard.id) if dirty
    end

    def deactivate_widget(widget)
      Rails.logger.info "In ResetGroup worker:: Updating widget:: #{widget.dashboard_id} :: #{widget.id}"
      config = widget.config_data
      widget.active = false
      widget.config_data.delete('group_ids') if config['group_ids']
      widget.config_data.delete('group_id') if config['group_id']
      widget.save
    end
end
