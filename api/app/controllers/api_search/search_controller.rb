module ApiSearch
  class SearchController < ApiApplicationController
    include SearchHelper

    private

      # Contructs a hash by collecting all values in the expression in the following format for validation
      # {
      #   priority: [2,3,4]
      #   status: [1,2]
      #   ........
      # }
      def record_from_expression_tree(tree)
        record = {}
        tree.each do |node|
          if node.type == :operand
            record[node.key] = [] unless record[node.key]
            record[node.key] << node.value
          end
        end
        record
      end

      # custom_field names mapped to equivalent column_names in the database and stored under the key 'custom_fields'
      def sanitize_custom_fields(hash, fields)
        record = ActionController::Parameters.new(hash)
        record.permit(*fields | custom_fields.values)

        record[:custom_fields] = {}
        custom_fields.each do |field_name, display_name|
          if record.key?(display_name)
            record[:custom_fields][field_name] = record.delete(display_name)
          end
        end
        record
      end

      def custom_fields
        # Returns the mapping where the key is the custom_field column_name with account id and value decorated column_name
      end

      def error_options_mappings
        custom_fields
      end

      # For the users we wont be displaying the custom_field name with account_id
      def set_custom_errors(item)
        ErrorHelper.rename_error_fields(@custom_fields, item)
      end

      def validate_filter_params
        params.permit(*ApiSearchConstants::FIELDS, *ApiSearchConstants::DEFAULT_INDEX_FIELDS)
        @url_validation = SearchUrlValidation.new(params, parser)
        render_errors @url_validation.errors, @url_validation.error_options unless @url_validation.valid?
      end

      def parser
        @parser ||= Search::V2::Parser::SearchParser.new
      end

      def query_results(search_terms, page, associations, type)
        begin
          @records = Search::V2::QueryHandler.new({
            account_id:   current_account.id,
            context:      :search_query_api,
            exact_match:  false,
            es_models:    associations,
            current_page: page,
            offset:       ApiSearchConstants::DEFAULT_PER_PAGE,
            types:        type,
            es_params:    { search_terms: search_terms.to_json, offset: (page - 1) * ApiSearchConstants::DEFAULT_PER_PAGE, size: ApiSearchConstants::DEFAULT_PER_PAGE }
          }).query_results
        rescue Exception => e
          Rails.logger.error "Searchv2 exception - #{e.message} - #{e.backtrace.first}"
          NewRelic::Agent.notice_error(e)
          @records = []
        end
        @records
      end
  end
end
