class ContactFilter < ActiveRecord::Base
  include Segments::InstanceMethods

  self.primary_key = :id
  serialize :data

  belongs_to_account

  attr_accessible :account_id, :data, :name

  validates :data, presence: true

  validate :query_hash_data

  after_commit :clear_cache

  def query_hash_data
    unless Segments::FilterDataValidation.new(data).valid?
      errors.add(:data, 'Invalid Query Hash')
    end
  end

  private

    def custom_field_types
      @custom_field_types ||= account.contact_custom_field_types
    end

    def allowed_default_fields
      ALLOWED_CONTACT_DEFAULT_FIELDS
    end

    def clear_cache
      account.clear_contact_filters_cache
    end
end
