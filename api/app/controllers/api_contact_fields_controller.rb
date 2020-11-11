class ApiContactFieldsController < ApiApplicationController
  decorate_views

  private

    def validate_filter_params
      # This method has been overridden to avoid validating pagination options.
    end

    def scoper
      contact_fields = current_account.contact_form.contact_fields
      return contact_fields.reject(&:twitter_field?) if mobile_app_request?

      contact_fields
    end

    def load_objects(items = scoper)
      # This method has been overridden to avoid pagination.
      @items = items
    end
end
