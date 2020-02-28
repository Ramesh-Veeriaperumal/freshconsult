class Helpdesk::Source < Helpdesk::Choice
  validates :name, presence: true
  validates :name, length: { in: 1..50 }
  validates :name, uniqueness: { scope: :account_id, case_sensitive: false }
  xss_sanitize only: [:name], plain_sanitizer: [:name]
  # Need to revisit during custom sources
  validates :account_choice_id, numericality: { less_than_or_equal_to: MAXIMUM_NUMBER_OF_SOURCES, scope: [:account_id, :type] }
end
