module Concerns::CustomerNote::Validations
  extend ActiveSupport::Concern

  included do
    validates :created_by, presence: true, numericality: { only_integer: true, greater_than: 0 }
    validates :last_updated_by, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validates :title, length: { maximum: 256 }
    validate :check_body_presence

    private

      def check_body_presence
        # when creating a new customer note: making sure body exists
        return errors.add :body, :blank unless note_body

        # when updating an existing customer note: Making sure body exists
        return errors.add :body, :blank if note_body._destroy == true
      end
  end
end
