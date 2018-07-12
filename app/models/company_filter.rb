class CompanyFilter < ActiveRecord::Base
  self.primary_key = :id
  serialize :data

  belongs_to_account

  attr_accessible :account_id, :data, :name

  validates :data, presence: true

  validate :query_hash_data

  def query_hash_data
    unless Segments::FilterDataValidation.new(data, self.class.name).valid?
      errors.add(:data, 'Invalid Query Hash')
    end
  end
end
