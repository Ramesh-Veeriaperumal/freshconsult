module Helpdesk::ApprovalConstants
  STATUSES = [
    [:in_review, 'approvals.status.in_review', 1],
    [:approved, 'approvals.status.approved',    2],
    [:rejected, 'approvals.status.rejected',    3]
  ].freeze
  STATUS_KEYS_BY_TOKEN = Hash[*STATUSES.map { |i| [i[0], i[2]] }.flatten]
  STATUS_NAMES_BY_KEY = Hash[*STATUSES.map { |i| [i[2], i[1]] }.flatten]
end
