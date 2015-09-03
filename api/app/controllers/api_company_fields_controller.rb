class ApiCompanyFieldsController < ApiApplicationController
  private

    def decorate_objects
      @items.map! { |item| ApiCompanyFieldsDecorator.new(item) }
    end

    def scoper
      current_account.company_form.company_fields
    end
end
