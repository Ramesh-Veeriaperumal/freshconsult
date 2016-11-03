module BulkActionConcern
  extend ActiveSupport::Concern

  private

    def bulk_action
      return unless validate_bulk_action_params
      sanitize_bulk_action_params
      fetch_objects
      yield
      render_bulk_action_response(bulk_action_succeeded_items, bulk_action_errors)
    end

    def validate_bulk_action_params
      action_fields = ApiConstants.const_defined?(action_name.upcase + '_FIELDS') ? "ApiConstants::#{action_name.upcase}_FIELDS".constantize : []
      field = ApiConstants::BULK_ACTION_FIELDS | action_fields
      params[cname].permit(*field)
      api_validation = ApiValidation.new(params, nil)
      return true if api_validation.valid?(action_name.to_sym)
      render_errors api_validation.errors, api_validation.error_options
      false
    end

    def sanitize_bulk_action_params
      prepare_array_fields ApiConstants::BULK_ACTION_ARRAY_FIELDS.map(&:to_sym)
    end

    def render_bulk_action_response(succeeded, failed)
      if async_process? || failed.any?
        render_partial_success(succeeded, failed)
      else
        head 204
      end
    end

    def bulk_action_errors
      @bulk_action_errors ||=
        params[cname][:ids].inject([]) do |a, e|
          error_hash = retrieve_error_code(e)
          error_hash.any? ? a << error_hash : a
        end
    end

    def retrieve_error_code(id)
      ret_hash = { :id => id, :errors => {}, :error_options => {} }
      if bulk_action_failed_items.include?(id)
        if @validation_errors && @validation_errors.key?(id)
          ret_hash[:validation_errors] = @validation_errors[id]
        else
          ret_hash[:errors].merge!({:id => :unable_to_perform })
        end
      elsif !bulk_action_succeeded_items.include?(id)
        ret_hash[:errors].merge!({:id => :"is invalid" })
      else
        return {}
      end
      return ret_hash
    end

    def bulk_action_succeeded_items
      @succeeded_ids ||= @items.map(&id_param) - bulk_action_failed_items
    end

    def bulk_action_failed_items
      @failed_ids ||= (@items_failed || []).map(&id_param)
    end

    def id_param
      @identifier ||= (@items || @items_failed || []).first.is_a?(Helpdesk::Ticket) ? (:display_id) : (:id)
    end 

    def async_process?
      ApiConstants::BULK_ACTION_ASYNC_METHODS.include?(action_name.to_sym)
    end
end
