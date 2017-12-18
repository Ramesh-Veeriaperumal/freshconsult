class ContactMergeDelegator < BaseDelegator
  attr_accessor :target_users

  validate :validate_target_ids, if: -> { @target_ids.present? }
  validate :check_unassociated_values, if: -> { @target_ids && errors[:target_ids].blank? }
  validate :check_mandatory_contact_fields, if: -> { @primary_email.blank? }

  def initialize(record, options = {})
    super(record)
    @target_ids = options[:target_ids]
    @user_hash = options[:params]
    @primary_email = record.send(:email)
    fetch_target_users(options[:scoper]) if @target_ids
  end

  def validate_target_ids
    invalid_ids = @target_ids - @target_users.map(&:id)
    if invalid_ids.any?
      errors[:target_ids] << :invalid_list
      error_options.merge!(target_ids: { list: invalid_ids.join(', ') })
    end
  end

  def check_unassociated_values
    @user_hash.each do |att_key, att_value|
      if att_value # can be nil
        all_values = fetch_attributes(att_key)
        att_values = att_value.to_a
        unassociated_values = att_values - all_values
        if (unassociated_values.uniq.length > 0)
          errors[ContactConstants::MERGE_FIELD_MAPPINGS.fetch(att_key.to_sym, att_key.to_sym)] << :unassociated_values
          error_options.merge!(ContactConstants::MERGE_FIELD_MAPPINGS.fetch(att_key.to_sym, att_key.to_sym) => { invalid_values: att_values.join(', ') })
        end
      end
    end
  end

  def check_mandatory_contact_fields
    if is_mandatory_field_required?
      errors[:contact] << :fill_a_mandatory_field
      error_options.merge!(:contact => { field_names: ContactConstants::MERGE_KEYS.join(', ') })
    end
  end

  def is_mandatory_field_required?
    ContactConstants::MERGE_KEYS.all? { |x| @user_hash[x].blank? && errors[x].blank? }
  end

  private

    def fetch_target_users(scoper)
      @target_users = scoper.without(self).where(id: @target_ids)
    end

    def fetch_attributes(att)
      [send(att), @target_users.map { |x| x.send(att) }].flatten.compact
    end
end
