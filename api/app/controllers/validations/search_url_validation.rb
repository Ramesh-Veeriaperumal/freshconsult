class SearchUrlValidation < ApiValidation
  attr_accessor :query, :page

  validates :page, custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param, less_than: ApiSearchConstants::MAX_PAGE + 1, custom_message: :per_page_invalid, message_options: { max_value: ApiSearchConstants::MAX_PAGE } }
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
