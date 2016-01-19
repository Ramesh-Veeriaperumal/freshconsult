class ApiCompanyFieldsController < ApiApplicationController
  decorate_views

  private

    def validate_filter_params
      # This method has been overridden to avoid validating pagination options.
    end

    def scoper
      current_account.company_form.company_fields
    end

    def load_objects(items = scoper)
      # This method has been overridden to avoid pagination.
      @items = items
    end
end
