class Solution::Template < ActiveRecord::Base
  self.table_name = 'solution_templates'

  self.primary_key = :id

  belongs_to_account
  belongs_to :author, class_name: 'User', foreign_key: 'user_id'
  belongs_to :recent_author, class_name: 'User', foreign_key: 'modified_by'

  has_many :solution_template_mappings,
           class_name: 'Solution::TemplateMapping',
           dependent: :destroy

  validates :account_id, presence: true
  validates :user_id, presence: true
  validates :title, presence: true

  scope :latest, -> { order('modified_at DESC') }
  scope :order_by_default_latest, -> { order('is_default DESC, modified_at DESC') }
  scope :default, -> { where(is_default: true) }

  before_validation :populate_user_id, on: :create
  before_validation :modify_date_and_author

  xss_sanitize only: [:title], plain_sanitizer: [:title]

  # modified details be changed iff there is a change in one or more below fields.
  FIELDS_TRACKED_FOR_CHANGES = ['title', 'description'].freeze

  def populate_user_id
    self.user_id = User.current.id
  end

  def modify_date_and_author
    if changes && !(changes.keys & FIELDS_TRACKED_FOR_CHANGES).empty?
      self.modified_at = Time.now.utc
      self.modified_by = User.current.id
    end
  end

  def description=(val)
    val = Helpdesk::HTMLSanitizer.sanitize_article(val)
    val = if Account.current.launched?(:encode_emoji_in_solutions)
            UnicodeSanitizer.utf84b_html_c(val)
          else
            UnicodeSanitizer.remove_4byte_chars(val)
          end
    self[:description] = val
  end
end
