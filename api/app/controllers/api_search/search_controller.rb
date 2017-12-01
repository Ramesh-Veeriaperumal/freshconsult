module ApiSearch
  class SearchController < ApiApplicationController
    include SearchHelper

    private

      def validate_filter_params
        params.permit(*ApiSearchConstants::FIELDS, *ApiSearchConstants::DEFAULT_INDEX_FIELDS)
        @url_validation = SearchUrlValidation.new(params)
        render_errors @url_validation.errors, @url_validation.error_options unless @url_validation.valid?
      end
  end
end
