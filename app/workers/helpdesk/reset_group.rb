class Helpdesk::ResetGroup < BaseWorker
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Cache::Memcache::Dashboard::Custom::CacheData
  include Redis::HashMethods
  include Dashboard::Custom::CacheKeys
  include BulkOperationsHelper

  sidekiq_options queue: :reset_group, retry: 0, failures: :exhausted
  BATCH_LIMIT = 50
  # 2 - csat 3 - leaderboard 5 - ticket_trend_card 6 - time_trend_card 7 - sla_trend_card
  DASHBOARD_GROUP_WIDGETS = [2, 3, 5, 6, 7].freeze

  def perform(args)
    args.symbolize_keys!
    @account = Account.current
    @group_id = args[:group_id]
    reason = args[:reason].symbolize_keys!
    options = { reason: reason, manual_publish: true, rate_limit: rate_limit_options(args) }

    Sharding.run_on_slave do
      handle_dashboards_widgets
      handle_group_tickets(options)
    end
  rescue Exception => e
    Rails.logger.info "Error in ResetGroup worker :: #{e.inspect}, #{args.inspect}"
    NewRelic::Agent.notice_error(e, args: args)
  end

  private

    def handle_group_tickets(options)
      update_all_params = [{ group_id: nil }, {}, options]
      tickets = @account.tickets.where(group_id: @group_id)
      tickets.update_all_with_publish(*update_all_params)
    end

    def handle_dashboards_widgets
      Rails.logger.info 'In ResetGroup worker:: Handling dashboards'
      account_dashboards = multi_get_all_redis_hash(dashboard_index_redis_key)
      account_dashboards.each do |id, dashboard_object|
        parsed_dashboard_object = JSON.parse(dashboard_object)
        update_dashboard_access(id) if parsed_dashboard_object['group_ids'] && parsed_dashboard_object['group_ids'].include?(@group_id)
      end
      update_widgets
    end

    def update_dashboard_access(dashboard_id)
      Rails.logger.info "In ResetGroup worker:: Deleting dashboard :: #{dashboard_id}"
      dashboard = @account.dashboards.find(dashboard_id)
      return unless dashboard

      Sharding.run_on_master do
        dashboard.destroy
      end
    end

    def update_widgets
      group_widgets_dashboards = @account.dashboards
                                         .joins(:widgets)
                                         .where('widget_type IN (?)', DASHBOARD_GROUP_WIDGETS)
                                         .includes(:widgets)
      return unless group_widgets_dashboards

      Sharding.run_on_master do
        group_widgets_dashboards.each do |dashboard|
          update_group_widgets(dashboard)
        end
      end
    end

    def update_group_widgets(dashboard)
      dirty = false
      dashboard.widgets.each do |widget|
        config = widget.config_data
        if (config['group_ids'] && config['group_ids'].include?(@group_id)) || config['group_id'] == @group_id
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
