class ApiCompanyFieldsController < ApiApplicationController
  private

    def scoper
      current_account.company_form.company_fields
    end
end
