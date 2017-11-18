module Freshquery::Constants
  QUERY_FORMAT_INVALID = "Given query is invalid, expected format \"keyword:value  OPERATOR keyword:'string' OPERATOR keyword:>'yyyy-mm-dd'\". Space is mandatory between key/value pair and operator. Please check the paranthesis if there are any.".freeze
  QUERY_LENGTH_INVALID = "Has %{current_count} characters, it can have maximum of %{max_count} characters".freeze
  STRING_WITHIN_QUOTES = /\"(.*)\"/.freeze
  ES_OPERATORS = { '<' => 'lte', '>' => 'gte', 'OR' => 'should', 'AND' => 'must' }.freeze
end.freeze
