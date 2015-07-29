class ApiContactFieldsController < ApiApplicationController

  private

    def scoper
      current_account.contact_form.contact_fields
    end

end
