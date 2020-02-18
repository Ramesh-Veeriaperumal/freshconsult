class HelpWidgetSuggestedArticleRule < ActiveRecord::Base
  EVALUATE_ON = {
    page: 1
  }.freeze

  NAME = {
    url: 1
  }.freeze

  ORDER_BY = {
    hits: 1
  }.freeze

  OPERATOR = {
    contains: 1
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
