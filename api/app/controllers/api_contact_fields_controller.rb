class ApiContactFieldsController < ApiApplicationController

  private

    def scoper
      current_account.contact_form.contact_fields
    end

    def load_objects(items = scoper)
      @items = items.paginate(paginate_options)
    end
end
