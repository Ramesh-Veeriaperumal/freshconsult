class ContactDelegator < BaseDelegator
  validates :company, presence: true, if: -> { company_id && changed.include?('customer_id') }
  validates :custom_field, custom_field: { custom_field: {
    validatable_custom_fields: proc { Account.current.contact_form.custom_drop_down_fields },
    drop_down_choices: proc { Account.current.contact_form.custom_dropdown_field_choices },
    required_attribute: :required_for_agent
  }
  }

  validate :user_emails_validation, if: -> { @other_emails }

  def initialize(record, other_emails = [])
    @other_emails = other_emails
    @user_id = record.id
    super(record)
  end

  # Web displays a generic error message "Email has already been taken" when we try to add emails associated to other users
  # It is displayed when the call to update_attributes fails
  # In API V2 the validation handled prior to the update_attributes call, also the error message will contain the list of erroneous emails
  def user_emails_validation
    # Find out the emails that are not associated to the current user
    invalid_emails = @other_emails.map { |x| x.email if id != x.user_id }.compact
    if invalid_emails.any?
      errors[:other_emails] << :already_taken
      @error_options = { other_emails: { invalid_emails: "#{invalid_emails.join(', ')}" }  }
    end
  end
end
