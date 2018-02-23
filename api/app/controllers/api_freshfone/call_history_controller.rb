module ApiFreshfone
  class CallHistoryController < ApiApplicationController
    include Redis::IntegrationsRedis
    include Export::Util
    include Rails.application.routes.url_helpers

    before_filter :validate_filter_params, only: [:export]
    skip_before_filter :load_object, only: [:export, :export_status] 
    before_filter  :validate_params, :data_export, only: [:export_status]

    EXPORT_TYPE = "call_history"

    def export 
      begin
        check_and_create_export EXPORT_TYPE
        @item = @data_export if @data_export.present?
        Resque.enqueue(Freshfone::Jobs::CallHistoryExport::CallHistoryExport, export_params)
        export_status
        render_202_with_location location_url: "export_status_api_freshfone_call_history_index_url"
      rescue Exception => e
        Rails.logger.error "Error initializing worker:\n#{e.backtrace.join('\n')}"
        render_base_error(:internal_error, 500)
      end
    end

    def export_status
      @export = {
        :id => export_id,
        :status => ApiFreshfone::CallHistoryConstants::EXPORT_STATUS_STR_HASH[@data_export.status]
      }
      @export[:download_url] = hash_url(current_account.host) if export_completed?
    end

    private

    def render_202_with_location(template_name: "#{controller_path.gsub(/pipe\/|channel\//, '')}/#{action_name}", location_url: "#{nscname}_url", item_id: @item.id)
      render template_name, location: safe_send(location_url, item_id), status: 202
    end

    def data_export
      @data_export ||= current_account.data_exports.find_by_id(params[:id])
      render_base_error(:not_found, 404) unless @data_export
    end

    def export_id
      @export_id ||= @data_export.id if @data_export
    end

    def export_completed?
      @data_export.completed?
    end

    def validate_filter_params
      params.permit(*CallHistoryConstants::EXPORT_FIELDS, *ApiConstants::DEFAULT_INDEX_FIELDS, cname)
      @call_history_filter = CallHistoryFilterValidation.new(params)
      render_errors(@call_history_filter.errors, @call_history_filter.error_options) unless @call_history_filter.valid?
    end

    def export_params
     {
      "api" => true,
      "number_id" => number_id || 0,
      "user_id" => current_user.id,
      "export_to" => params[:export_format] || 'csv',
      "export_id" => export_id,  
      "data_hash" => data_hash.to_json
      }.reject{|k,v| v.blank?}
    end

    def number_id
      active_numbers = current_account.freshfone_numbers.active_number(params[:number]) if params[:number].present?
      active_numbers.first.id if active_numbers.present?
    end

    def data_hash
      @data_hash ||= []
      @data_hash << created_at_hash if created_at_hash.present?
      @data_hash << call_type_hash if call_type_hash.present?
      @data_hash << user_id_hash if user_id_hash.present?
      @data_hash << customer_id_hash if customer_id_hash.present?
      @data_hash << group_id_hash if group_id_hash.present?
      @data_hash << business_hour_hash if business_hour_hash.present?
      @data_hash
    end

    def created_at_hash
      if params[:start_date].present? && params[:end_date].present?
        start_date = DateTime.iso8601(params[:start_date]) 
        end_date = DateTime.iso8601(params[:end_date]) 
        value = "#{start_date.strftime('%c')} - #{end_date.strftime('%c')}}" 
      end
      value = default_time_range if no_time_range_given?
      @create_at_hash ||= {"condition"=> "created_at", "operator" => "is_in_the_range", "value"=> value} if value.present?
    end

    def call_type_hash
      @call_type_hash ||= {"condition"=> "call_type", "operator"=> "is", "value"=> params[:call_type]} if params[:call_type].present?
    end

    def user_id_hash
      @user_id_hash ||= {"condition"=> "user_id", "operator"=> "is_in", "value"=> params[:user_ids].join(',')} if params[:user_ids].present?
    end

    def customer_id_hash
      @customer_id_hash ||= {"condition"=> "customer_id", "operator"=> "is", "value"=> params[:requester_id]} if params[:requester_id].present?
    end

    def group_id_hash
      @group_id_hash ||= {"condition"=> "group_id", "operator"=> "is", "value"=> params[:group_id]} if params[:group_id].present?
    end

    def business_hour_hash
      @business_hour_hash ||= {"condition"=> "business_hour_call", "operator"=> "is", "value"=> params[:business_hour_call]} if params[:business_hour_call].present?
    end

    def default_time_range
      "#{7.days.ago.strftime('%c')} - #{Time.now.strftime('%c')}"
    end

    def no_time_range_given?
      params[:start_date].blank? && params[:end_date].blank?
    end
  end
end
