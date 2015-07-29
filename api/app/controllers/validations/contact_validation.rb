class ContactValidation < ApiValidation
  attr_accessor :address, :avatar_attributes, :client_manager, :custom_fields, :company_id, :description, :email, :fb_profile_id, :job_title, :language,
                :mobile, :name, :phone, :tags, :time_zone, :twitter_id

  
  validates :avatar_attributes, data_type: { rules: Hash }, allow_nil: true
  validates :client_manager, custom_inclusion: { in: ApiConstants::BOOLEAN_VALUES }, allow_nil: true
  validates :company_id, required: { allow_nil: false }, if: :client_manager_set?, numericality: true
  validates :custom_fields, data_type: { rules: Hash }, allow_nil: true
  validates :email, format: { with: AccountConstants::EMAIL_REGEX, message: 'not_a_valid_email' }, allow_nil: true
  validates :language, custom_inclusion: { in: I18n.available_locales.map(&:to_s) }, allow_nil: true
  validates :name, required: { allow_nil: false }
  validates :tags, data_type: { rules: Array }, allow_nil: true
  validates :time_zone, custom_inclusion: { in: proc {  ActiveSupport::TimeZone.all.map { |time_zone| time_zone.name } } }, allow_nil: true
  
  validate :contact_detail_missing

  private

    def client_manager_set?
      client_manager == true
    end

    def contact_detail_missing
      if email.blank? && mobile.blank? && phone.blank? && twitter_id.blank?
        errors.add(:email,'Please fill at least 1 of email, mobile, phone, twitter_id fields.') 
        errors.add(:phone,'Please fill at least 1 of email, mobile, phone, twitter_id fields.') 
        errors.add(:mobile,'Please fill at least 1 of email, mobile, phone, twitter_id fields.') 
        errors.add(:twitter,'Please fill at least 1 of email, mobile, phone, twitter_id fields.') 

      end
    end
end