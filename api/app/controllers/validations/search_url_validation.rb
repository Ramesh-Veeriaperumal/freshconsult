class SearchUrlValidation < FilterValidation
  attr_accessor :query

  validates :query, data_type: { rules: String, required: true }, custom_length: { maximum: ApiSearchConstants::QUERY_SIZE }
  validate :validate_query, if: -> { errors[:query].blank? && query }

  def initialize(request_params, parser)
    @parser = parser
    super(request_params, nil, true)
  end

  def validate_query
    # Query is valid if it is given between '"' and '"'
    @query.strip!
    if @query !~ ApiSearchConstants::STRING_WITHIN_QUOTES
      errors[:query] << :query_format_invalid
    else
      begin
        @query = @parser.parse(@query[1, query.length-2])
      rescue Exception => e
        errors[:query] << e.message
      end
    end
  end
end
