class ApiContactFieldsController < ApiApplicationController
  private

    def decorate_objects
      @items.map! { |item| ApiContactFieldsDecorator.new(item) }
    end

    def scoper
      current_account.contact_form.contact_fields
    end
end
