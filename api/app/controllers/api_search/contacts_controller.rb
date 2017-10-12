module ApiSearch
  class ContactsController < SearchController
    decorate_views
    def index
      tree = parser.expression_tree
      record = record_from_expression_tree(tree)

      record = sanitize_custom_fields(record, ApiSearchConstants::CONTACT_FIELDS)

      validation_params = record.merge(contact_fields: contact_fields)

      validation = Search::ContactValidation.new(validation_params, contact_custom_fields)

      if validation.valid?
        search_terms = tree.accept(visitor)
        page = params[:page] ? params[:page].to_i : ApiSearchConstants::DEFAULT_PAGE
        @items = query_results(search_terms, page, ApiSearchConstants::CONTACT_ASSOCIATIONS, ['user'])
      else
        render_custom_errors(validation, true)
      end
    end

    private

      def custom_fields
        @custom_fields ||= Account.current.contact_form.custom_contact_fields.each_with_object({}) { |field, hash| hash[field.name] = CustomFieldDecorator.display_name(field.name) if field.column_name =~ ApiSearchConstants::CUSTOMER_FIELDS_REGEX }
      end

      def visitor
        column_names = Account.current.contact_form.custom_contact_fields.each_with_object({}) { |field, hash| hash[CustomFieldDecorator.display_name(field.name)] = field.column_name if field.column_name =~ ApiSearchConstants::CUSTOMER_FIELDS_REGEX }.except(*ApiSearchConstants::CONTACT_FIELDS)
        es_keys = ApiSearchConstants::CONTACT_KEYS
        # date_fields = contact_fields.map(&:column_name).select { |x| x if x =~ /^cf_date/ } + ApiSearchConstants::CUSTOMER_DATE_FIELDS.map{|x| es_keys.fetch(x,x) }
        date_fields = ApiSearchConstants::CUSTOMER_DATE_FIELDS
        Search::TermVisitor.new(column_names, es_keys, date_fields, ApiSearchConstants::CONTACT_NOT_ANALYZED)
      end

      def allowed_custom_fields
        # If any custom fields have the name same as that of default fields it will be ignored
        contact_custom_fields.each_with_object({}) { |contact_field, hash| hash[contact_field.name] = CustomFieldDecorator.display_name(contact_field.name) unless ApiSearchConstants::CONTACT_FIELDS.include?(CustomFieldDecorator.display_name(contact_field.name)) }
      end

      def contact_custom_fields
        contact_fields.select { |x| ApiSearchConstants::ALLOWED_CUSTOM_FIELD_TYPES.include?(x.field_type.to_s) }
      end

      def contact_fields
        Account.current.contact_form.contact_fields_from_cache
      end

      def decorator_options
        super({ name_mapping: custom_fields })
      end
  end
end
