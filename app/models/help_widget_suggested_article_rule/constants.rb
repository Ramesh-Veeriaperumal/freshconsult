class HelpWidgetSuggestedArticleRule < ActiveRecord::Base
  OPERATOR_SET = [
    [:contains, 'include?', 1].freeze
  ].freeze

  NAME_SET = [
    [:url, 'HTTP_REFERER', 1].freeze
  ].freeze

  OPERATOR = Hash[*OPERATOR_SET.map { |i| [i[0], i[2]] }.flatten].freeze

  OPERATOR_VALUE_MAPPING = Hash[*OPERATOR_SET.map { |i| [i[2], i[1]] }.flatten].freeze

  NAME = Hash[*NAME_SET.map { |i| [i[0], i[2]] }.flatten].freeze

  NAME_VALUE_MAPPING = Hash[*NAME_SET.map { |i| [i[2], i[1]] }.flatten].freeze

  EVALUATE_ON = {
    page: 1
  }.freeze

  ORDER_BY = {
    hits: 1
  }.freeze

  RULE_OPERATOR = {
    OR: 1,
    AND: 2
  }.freeze

  FILTER_TYPE = {
    article: 1,
    tag: 2,
    folder: 3
  }.freeze

  DEFAULT_CONDITION = {
    evaluate_on: EVALUATE_ON[:page],
    name: NAME[:url],
    operator: OPERATOR[:contains]
  }.freeze

  DEFAULT_FILTER = {
    type: FILTER_TYPE[:article],
    order_by: ORDER_BY[:hits]
  }.freeze
end
