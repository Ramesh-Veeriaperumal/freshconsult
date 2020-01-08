module Helpdesk::ApprovalConstants
  STATUSES = [
    [:in_review, 'approvals.status.in_review', 1],
    [:approved, 'approvals.status.approved',    2],
    [:rejected, 'approvals.status.rejected',    3]
  ].freeze
  STATUS_KEYS_BY_TOKEN = Hash[*STATUSES.map { |i| [i[0], i[2]] }.flatten].freeze
  STATUS_TOKEN_BY_KEY = Hash[*STATUSES.map { |i| [i[2], i[0]] }.flatten].freeze
  STATUS_NAMES_BY_KEY = Hash[*STATUSES.map { |i| [i[2], i[1]] }.flatten].freeze

  IRIS_NOTIFICATION_TYPE = {
    STATUS_KEYS_BY_TOKEN[:in_review] => 'article_approval_in_review',
    STATUS_KEYS_BY_TOKEN[:approved] => 'article_approval_approved'
  }.freeze
end
