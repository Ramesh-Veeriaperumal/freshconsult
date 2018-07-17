module Segments
  class EsFilter
    CONTACT = 'contacts'.freeze

    def initialize(params, type = CONTACT)
      @data = params
      @segment_type = type
    end

    def fetch_result
      query_data = Segments::EsQueryBuilder.new(@data[:query_hash], contact_segment?).generate
      fq_builder = Freshquery::Builder.new.query do |builder|
        builder[:account_id]    = Account.current.id
        builder[:context]       = search_params[:context]
        builder[:current_page]  = @data[:page] ? @data[:page].to_i : ApiSearchConstants::DEFAULT_PAGE
        builder[:types]         = search_params[:types]
        builder[:es_models]     = search_params[:es_models]
        builder[:query]         = query_data
      end
      response = fq_builder.response
      Rails.logger.info("Query data and Query Error Message :: #{query_data.inspect} #{response.errors.inspect}") unless response.valid?
      response.items
    end

    def contact_search_params
      {
        context: :search_contact_api,
        types: ['user'],
        es_models: ApiSearchConstants::CONTACT_ASSOCIATIONS
      }
    end

    def company_search_params
      {
        context: :search_company_api,
        types: ['company'],
        es_models: ApiSearchConstants::COMPANY_ASSOCIATIONS
      }
    end

    def search_params
      @search_params ||= contact_segment? ? contact_search_params : company_search_params
    end

    def contact_segment?
      CONTACT.include?(@segment_type)
    end
  end
end
