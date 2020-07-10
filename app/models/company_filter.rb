class CompanyFilter < ActiveRecord::Base
  include Segments::InstanceMethods

  self.primary_key = :id
  serialize :data, Array

  belongs_to_account

  has_many :folder_visibility_mapping, class_name: 'Solution::FolderVisibilityMapping', as: 'mappable', dependent: :destroy

  has_many :folder_meta, class_name: 'Solution::FolderMeta', through: :folder_visibility_mapping

  attr_accessible :account_id, :data, :name

  validates :data, presence: true

  validate :query_hash_data

  after_commit :clear_cache

  def query_hash_data
    unless Segments::FilterDataValidation.new(data, self.class.name).valid?
      errors.add(:data, 'Invalid Query Hash')
    end
  end

  private

    def custom_field_types
      @custom_field_types ||= account.company_custom_field_types
    end

    def allowed_default_fields
      ALLOWED_COMPANY_DEFAULT_FIELDS
    end

    def clear_cache
      account.clear_company_filters_cache
    end
end
