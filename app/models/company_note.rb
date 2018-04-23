class CompanyNote < ActiveRecord::Base
  include Concerns::CustomerNote::Associations
  include Concerns::CustomerNote::Validations
  include Concerns::CustomerNote::Constants
  include Concerns::CustomerNote::Callbacks
  include Concerns::CustomerNote::Methods

  self.primary_key = :id

  belongs_to :company

  attr_accessible :category_id, :company_id

  validates :company_id, presence: true, numericality: { only_integer: true }
  validates :category_id, presence: true, numericality: { only_integer: true }
  validates :category_id, inclusion: { in: CATEGORIES.values } # change to note_categories id once table is implemented

  def initialize(attributes = {}, options = {})
    super
    self.category_id ||= 1
  end
end
