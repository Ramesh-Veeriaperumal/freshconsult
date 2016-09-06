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
      params[cname].permit(*ApiConstants::BULK_ACTION_FIELDS)
      api_validation = ApiValidation.new(params, nil)
      return true if api_validation.valid?(action_name.to_sym)
      render_errors api_validation.errors, api_validation.error_options
      false
    end

    def sanitize_bulk_action_params
      prepare_array_fields ApiConstants::BULK_ACTION_ARRAY_FIELDS.map(&:to_sym)
    end

    def render_bulk_action_response(succeeded, errors)
      if async_process? || errors.any?
        render_partial_success(succeeded, errors)
      else
        head 204
      end
    end

    def async_process?
      ApiConstants::BULK_ACTION_ASYNC_METHODS.include?(action_name.to_sym)
    end
end
