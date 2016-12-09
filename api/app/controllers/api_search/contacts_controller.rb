module ApiSearch
  class ContactsController < SearchController

    def index
      tree = parser.expression_tree
      record = record_from_expression_tree(tree)

      sanitize_custom_fields(record, ApiSearchConstants::CONTACT_FIELDS) if custom_fields.any?

      validation_params = record.merge({contact_fields: contact_fields })

      validation = Search::ContactValidation.new(validation_params)

      if validation.valid?
        @name_mapping = custom_fields
        search_terms = tree.accept(visitor)
        page = params[:page] ? params[:page].to_i : 1
        response = query_es(search_terms, :contacts)
        @items = query_results(response, page, ApiSearchConstants::CONTACT_ASSOCIATIONS)
      else
        render_custom_errors(validation, true)
      end
    end

    private

      def custom_fields
        @custom_fields ||= contact_custom_fields.each_with_object({}) { |field, hash| hash[field.name] =  CustomFieldDecorator.display_name(field.name) }
      end

      def visitor
        column_names = contact_custom_fields.each_with_object({}) { |field, hash| hash[CustomFieldDecorator.display_name(field.name).to_sym] = field.column_name }
        Search::TermVisitor.new(column_names)
      end

      def contact_custom_fields
        contact_fields.select{|x| ApiSearchConstants::ALLOWED_CUSTOM_FIELD_TYPES.include? x.field_type.to_s }
      end

      def contact_fields
        Account.current.contact_form.contact_fields_from_cache
      end
  end
end
