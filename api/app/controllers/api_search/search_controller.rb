module ApiSearch
  class SearchController < ApiApplicationController
    include SearchHelper

    private

      def record_from_expression_tree(tree)
        record = ActionController::Parameters.new
        tree.each do |node|
          if node.type == :operand
            record[node.key] = [] unless record[node.key]
            record[node.key] += [node.value]
          end
        end
        record
      end

      def sanitize_custom_fields(record, fields)
        record.permit(*fields | custom_fields.values)

        record[:custom_fields] = {}
        custom_fields.each do |field_name, display_name|
          if record.key?(display_name)
            record[:custom_fields][field_name] = record.delete(display_name)
          end
        end
      end

      def custom_fields
        # redefine in subclass
      end

      def set_custom_errors(item)
        ErrorHelper.rename_error_fields(@custom_fields, item)
      end

      def error_options_mappings
        custom_fields
      end

      def validate_filter_params
        params.permit(*ApiSearchConstants::FIELDS, *ApiSearchConstants::DEFAULT_INDEX_FIELDS)
        @url_validation = SearchUrlValidation.new(params, parser)
        render_errors @url_validation.errors, @url_validation.error_options unless @url_validation.valid?
      end

      def parser
        @parser ||= Search::V2::Parser::SearchParser.new
      end

      def query_results(es_results, page, associations)
        begin
          @records = Search::Utils.load_records(es_results, associations,
            {
              current_account_id: current_account.id,
              page: page,
              es_offset: 30
            }
          )
        rescue Exception => e
          Rails.logger.error "Searchv2 exception - #{e.message} - #{e.backtrace.first}"
          NewRelic::Agent.notice_error(e)
          @records = []
        end
        @records
      end
  end
end
