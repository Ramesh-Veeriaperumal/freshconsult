module Freshquery::Constants
	DEFAULT_QUERY_LENGTH = 8192
	DEFAULT_PER_PAGE = 30
	DEFAULT_PAGE = 1
  QUERY_FORMAT_INVALID = "Given query is invalid, expected format \"keyword:value  OPERATOR keyword:'string' OPERATOR keyword:>'yyyy-mm-dd' OPERATOR keyword:<integer\". Space is mandatory between key/value pair and operator. Please check the paranthesis if there are any.".freeze
  QUERY_LENGTH_INVALID = "Has %{current_count} characters, it can have maximum of %{max_count} characters".freeze
  STRING_WITHIN_QUOTES = /\"(.*)\"/.freeze
  ES_OPERATORS = { '<' => 'lte', '>' => 'gte', 'OR' => 'should', 'AND' => 'must' }.freeze
  CUSTOM_FIELDS_NAME = { "custom_string" => "custom_single_line_texts.not_analyzed", "custom_number" => "custom_numbers", "custom_dropdown" => "custom_dropdowns.not_analyzed" }.freeze
end
