class Solution::Template < ActiveRecord::Base
  self.table_name = 'solution_templates'

  self.primary_key = :id

  belongs_to_account
  belongs_to :author, class_name: 'User', foreign_key: 'user_id'
  belongs_to :recent_author, class_name: 'User', foreign_key: 'modified_by'

  validates :account_id, presence: true
  validates :user_id, presence: true
  validates :title, presence: true

  scope :latest, -> { order('modified_at DESC') }
  scope :default, -> { where(is_default: true) }

  before_validation :populate_user_id, on: :create
  before_validation :modify_date_and_author

  # modified details be changed iff there is a change in one or more below fields.
  FIELDS_TRACKED_FOR_CHANGES = ['title', 'description'].freeze

  def populate_user_id
    # TODO: Need to check when user id is nil, Validation should take care of that.
    self.user_id = User.current.id
  end

  def modify_date_and_author
    if changes && !(changes.keys & FIELDS_TRACKED_FOR_CHANGES).empty?
      self.modified_at = Time.now.utc
      self.modified_by = User.current.id
    end
  end
end
