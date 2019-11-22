class ContactMergeDelegator < BaseDelegator
  include ContactsCompaniesHelper
  
  attr_accessor :secondary_contacts, :primary_fields

  validate :validate_secondary_contact_ids, if: -> { @secondary_contact_ids.present? }
  validate :check_conflicts
  validate :check_unassociated_values, if: -> { @secondary_contact_ids && errors[:secondary_contact_ids].blank? }
  validate :check_mandatory_contact_fields
  validate :check_email_conflicts
  validate :check_company_conflicts, unless: -> { @user_hash.key?(:company_ids) }

  def initialize(record, options = {})
    super(record)
    @secondary_contact_ids = options[:secondary_contact_ids]
    @user_hash = options[:params]
    @primary_email = record.safe_send(:email)
    @primary_fields = {}
    fetch_secondary_contacts(options[:scoper]) if @secondary_contact_ids
  end

  def validate_secondary_contact_ids
    invalid_ids = @secondary_contact_ids - @secondary_contacts.map(&:id)
    if invalid_ids.any?
      errors[:secondary_contact_ids] << :invalid_list
      error_options[:secondary_contact_ids] = { list: invalid_ids.join(', ') }
    end
    merged_ids = @secondary_contacts.select(&:parent_id?).map(&:id)
    if merged_ids.any? && errors[:secondary_contact_ids].blank?
      errors[:secondary_contact_ids] << :merged_list
      error_options[:secondary_contact_ids] = { list: merged_ids.join(', ') }
    end
    deleted_ids = @secondary_contacts.select(&:deleted).map(&:id)
    deleted_ids -= merged_ids
    if deleted_ids.any? && errors[:secondary_contact_ids].blank?
      errors[:secondary_contact_ids] << :deleted_list
      error_options.merge!(secondary_contact_ids: { list: deleted_ids.join(', ') })
    end
  end

  def check_unassociated_values
    @user_hash.except(:email, :other_emails).each do |att_key, att_value|
      next if att_value.blank? # can be nil
      all_values = fetch_attributes(att_key)
      att_values = att_value.to_a
      unassociated_values = att_values - all_values
      unless unassociated_values.uniq.empty?
        errors[ContactConstants::MERGE_FIELD_MAPPINGS.fetch(att_key.to_sym, att_key.to_sym)] << :unassociated_values
        error_options.merge!(ContactConstants::MERGE_FIELD_MAPPINGS.fetch(att_key.to_sym, att_key.to_sym) => { invalid_values: unassociated_values.join(', ') })
      end
    end
  end

  def check_mandatory_contact_fields
    if mandatory_field_required?
      errors[:contact] << :fill_a_mandatory_field
      error_options.merge!(contact: { field_names: (ContactConstants::MERGE_MANDATORY_FIELDS - [:external_id]).join(', ') })
    end
  end

  def mandatory_field_required?
    ContactConstants::MERGE_MANDATORY_FIELDS.all? { |x| fields_required?(@user_hash, x) && errors[x].blank? }
  end

  def fields_required?(user_hash, field)
    if user_hash.key?(field)
      return true if user_hash[field].blank?
    elsif fetch_attributes(field).blank?
      return true
    end
    false
  end

  def check_conflicts
    # Checking for conflicts when field is not present but contacts have values
    (ContactConstants::MERGE_KEYS - [:external_id]).each do |field|
      all_values = fetch_attributes(field).uniq.reject(&:blank?)
      next if @user_hash.key?(field) || all_values.count <= 1
      errors[field] << :fill_a_value
      error_options[field] = { values: all_values.join(', ') }
    end
  end

  def check_email_conflicts
    @primary_fields[:email] = fetch_attributes(:email).first
    @primary_fields[:other_emails] = fetch_attributes(:emails)
    if !@user_hash.key?(:other_emails) && (@primary_fields[:other_emails].count > User::MAX_USER_EMAILS)
      errors[:other_emails] << :fill_values_upto_max_limit
      error_options[:other_emails] = { values: @primary_fields[:other_emails].join(', '),
                                       max_limit: ContactConstants::MAX_OTHER_EMAILS_COUNT }
    end
  end

  def check_company_conflicts
    @primary_fields[:company_ids] = fetch_attributes(:company_ids).uniq
    return if @primary_fields[:company_ids].length <= 1
    if !Account.current.multiple_user_companies_enabled?
      errors[:company_ids] << :fill_a_value
      error_options[:company_ids] = { values: @primary_fields[:company_ids].join(', ') }
    elsif @primary_fields[:company_ids].length > user_companies_limit
      errors[:company_ids] << :fill_values_upto_max_limit
      error_options[:company_ids] = { values: @primary_fields[:company_ids].join(', '),
                                      max_limit: user_companies_limit }
    end
  end

  private

    def fetch_secondary_contacts(scoper)
      @secondary_contacts = scoper.without(self).where(id: @secondary_contact_ids)
    end

    def fetch_attributes(att)
      [send(att), @secondary_contacts.map { |x| x.safe_send(att) }].flatten.compact
    end
end
