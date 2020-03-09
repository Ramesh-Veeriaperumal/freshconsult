module ApiSearch
  class ContactsController < SearchController
    decorate_views
    def index
      fq_builder = construct_fq_builder(construct_options)
      response = fq_builder.response
      if response.valid?
        @items = response.items
      else
        render_errors response.errors, response.error_options
      end
    end

    private

    def construct_fq_builder(options = {})
      fq_obj = Freshquery::Builder.new.query do |builder|
        builder[:account_id]    = current_account.id
        builder[:context]       = :search_contact_api
        builder[:current_page]  = params[:page] ? params[:page].to_i : ApiSearchConstants::DEFAULT_PAGE
        builder[:types]         = ['user']
        builder[:es_models]     = ApiSearchConstants::CONTACT_ASSOCIATIONS
        builder[:es_params]     = options[:es_params] if options[:es_params].present?
        builder[:query]         = params[:query]
      end
      fq_obj
    end

    def construct_options
      private_api? ? { es_params: { include_deleted: true } } : {}
    end

    def decorator_options
      super({ name_mapping: Account.current.contact_form.custom_contact_fields.each_with_object({}) { |field, hash| hash[field.name] = CustomFieldDecorator.display_name(field.name) } })
    end
  end
end
