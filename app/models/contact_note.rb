class ContactNote < ActiveRecord::Base
  include Concerns::CustomerNote::Associations
  include Concerns::CustomerNote::Validations
  include Concerns::CustomerNote::Constants
  include Concerns::CustomerNote::Callbacks
  include Concerns::CustomerNote::Methods

  belongs_to :user
  self.primary_key = :id

  validates :user_id, presence: true, numericality: { only_integer: true }

  attr_accessible :user_id
end
