module ApiIntegrations
  class CtiController < ApiApplicationController
    include Redis::RedisKeys
    include Redis::IntegrationsRedis
    decorate_views

    def create
      @item.status = Integrations::CtiCall::NONE
      if @item.save
        cti_redis_key = INTEGRATIONS_CTI % { account_id: current_account.id, user_id: @item.responder_id }
        is_pop_open = get_integ_redis_key(cti_redis_key)
        Integrations::CtiWorker.perform_async(@item.id) if is_pop_open.present? && is_pop_open.to_bool
      else
        render_custom_errors(@item)
      end
    end

    private

      def validate_params
        allowed_fields = nil
        if params[cname][:call_info].is_a?(Hash)
          allowed_fields = ApiIntegrations::CtiConstants::SCREEN_POP_FIELDS | [call_info: params[cname][:call_info].keys] # small hack to allow dynamic hashes
        else
          allowed_fields = ApiIntegrations::CtiConstants::SCREEN_POP_FIELDS | [:call_info]
        end
        params[cname].permit(*(allowed_fields))
        cti_call = ApiIntegrations::CtiValidation.new(params[cname], @item)
        render_custom_errors(cti_call, true)  unless cti_call.valid?
      end

      def validate_filter_params
        params.permit(*ApiIntegrations::CtiConstants::INDEX_FIELDS, *ApiConstants::DEFAULT_INDEX_FIELDS)
        @cti_filter = CtiFilterValidation.new(params, nil)
        render_errors(@cti_filter.errors, @cti_filter.error_options) unless @cti_filter.valid?
      end

      def load_objects
        super scoper.where(call_sid: params[:call_reference_id])
      end

      def set_custom_errors(item = @item)
        ErrorHelper.rename_error_fields(ApiIntegrations::CtiConstants::RENAME_ERROR_FIELDS, item)
      end

      def sanitize_params
        params[cname][:options] = params[cname].dup
        ApiIntegrations::CtiConstants::EXCLUDE_FIELDS.each do |x|
          params[cname].delete(x)
        end
      end

      def scoper
        current_account.cti_calls
      end

      def feature_name
        ApiIntegrations::CtiConstants::FEATURE_NAME
      end
  end
end
