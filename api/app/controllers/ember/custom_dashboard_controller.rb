module Ember
  class CustomDashboardController < ApiApplicationController
    include HelperConcern
    include ::Dashboard::Custom::CustomDashboardConstants
    include Cache::Memcache::Dashboard::Custom::MemcacheKeys
    include Cache::Memcache::Dashboard::Custom::CacheData
    include Redis::RedisKeys
    include Redis::HashMethods
    include CustomDashboardConcern
    include ::Dashboard::Custom::CacheKeys

    SLAVE_ACTIONS = %w(index, widgets_data bar_chart_data)

    skip_before_filter :load_object, only: [:widget_data_preview, :show, :omni_widget_data_preview]

    before_filter :load_dashboard_from_cache, only: :show
    before_filter :load_objects, only: :index
    before_filter :load_announcement, only: :fetch_announcement

    def create
      if @item.save
        @item = dashboard_details_hash(@item)
        render 'ember/custom_dashboard/show', status: 201
      else
        render_errors(@item.errors)
      end
    end

    def show
      if @item.nil?
        log_and_render_404
      elsif !dashboard_accessible?
        access_denied
      end
    end

    def index; end

    def widgets_data
      begin    
        safe_send(params['type']) if validate_type
      rescue SearchService::Errors::InvalidJsonException
        render_request_error :internal_error, 400 # Handling known 500 as 400.
      end
    end

    def widget_data_preview
      safe_send("#{params['type']}_preview") if validate_type
    end

    def bar_chart_data
      @bar_chart_result = {}
      widget = @item.bar_chart_widgets_from_cache.select { |w| w.id == params['widget_id'].to_i }[0]
      head 404 and return unless widget
      config = widget.config_data.merge(view_all: true)
      config[:ticket_filter_id] = widget.ticket_filter_id unless widget.config_data['ticket_filter_id']
      @bar_chart_result = ::Dashboard::Custom::BarChart.new(nil, config).preview
    end

    def update
      return unless validate_body_params
      delegator_params = build_delegator_hash
      return unless validate_delegator(@item, delegator_params)
      assign_dashboard_attributes
      @item.touch unless @item.changed?
      if @item.save
        @item = dashboard_details_hash(@item)
        render 'ember/custom_dashboard/show'
      else
        render_errors(@item.errors)
      end
    end

    def destroy
      @item.destroy
      head 204
    end

    def create_announcement
      return unless validate_req_params(@item, announcement_text: params[:announcement_text])
      build_announcement
      @dashboard_announcement.save ? @announcement = announcement_for_dashboard : render_errors(@dashboard_announcement.errors)
    end

    def end_announcement
      @announcement = @item.announcements.active.first
      head 404 and return unless @announcement
      @result = @announcement.deactivate ? { success: true } : render_errors(@announcement.errors)
    end

    def get_announcements
      @announcements, response.api_meta = fetch_announcements_with_count(params['page'])
    end

    def fetch_announcement
      @announcement = fetch_announcement_with_viewers
    end

    def omni_widget_data
      return access_denied unless Account.current.omni_channel_team_dashboard_enabled? && dashboard_accessible?

      @widget = @item.widgets.find_by_id(params[:widget_id])
      head 404 && return unless @widget
      @response, code = OmniChannelDashboard::Client.new(@widget.url, :get).widget_data_request
      render "#{controller_path}/omni_widget_data", status: code
    end

    def omni_widget_data_preview
      return access_denied unless Account.current.omni_channel_team_dashboard_enabled? && omni_preview_accesible?(params[:source])

      valid_module = valid_omni_widget_module?(params)
      if valid_module == true
        url = OmniChannelDashboard::Constants::BASE_URL + params.except(:version, :format, :controller, :action, :id).to_query
        @response, code = OmniChannelDashboard::Client.new(url, :get).widget_data_request
        render "#{controller_path}/omni_widget_data", status: code
      else
        render_request_error(:invalid_values, 400, valid_module)
      end
    end

    private

      WIDGET_MODULE_NAMES.each do |module_name|
        module_klass = WIDGET_MODULES_BY_KLASS[module_name].constantize

        define_method module_name.to_s do
          result = MemcacheKeys.fetch(safe_send("#{module_name}_cache_key", @item.id), module_klass::CACHE_EXPIRY) do
            {
              widgets: module_klass.new(@item).result,
              last_dump_time: Time.now.to_i
            }
          end
          @widgets_result = result[:widgets]
          response.api_meta = { last_dump_time: result[:last_dump_time], dashboard: { last_modified_since: @item.updated_at.to_i } }
        end

        define_method "#{module_name}_preview" do
          options = params.slice(*"#{constants_class}::#{module_name.upcase}_PREVIEW_FIELDS".constantize)
          valid_module = module_klass.valid_config?(options)
          if valid_module == true
            @preview_data = module_klass.new(nil, options).preview
            render_base_error(:internal_error, @preview_data[:status]) if @preview_data[:error]
          elsif valid_module[:feature].present?
            render_request_error(:require_feature, 403, feature: valid_module[:feature])
          else
            render_request_error(:invalid_values, 400, valid_module)
          end
        end
      end

      def validate_type
        unless WIDGET_MODULE_NAMES.include?(params['type'])
          render_request_error :invalid_values, 400, fields: 'type'
          return false
        end
        true
      end

      def set_root_key
        response.api_root_key = ROOT_KEY[action_name.to_sym] if ROOT_KEY[action_name.to_sym]
      end

      def dashboard_cache_key(dashboard_id)
        CUSTOM_DASHBOARD % { account_id: current_account.id, dashboard_id: dashboard_id }
      end

      def constants_class
        '::Dashboard::Custom::CustomDashboardConstants'.freeze
      end

      def feature_name
        :custom_dashboard
      end

      def scoper
        current_account.dashboards
      end
  end
end
