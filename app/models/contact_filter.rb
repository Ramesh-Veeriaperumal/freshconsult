class ContactFilter < ActiveRecord::Base
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

    def clear_cache
      account.clear_contact_filters_cache
    end
end
