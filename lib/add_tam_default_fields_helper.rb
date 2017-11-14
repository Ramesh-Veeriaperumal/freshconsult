module AddTamDefaultFieldsHelper

  include CompanyFieldsConstants

  DEFAULT_FIELDS =
    [
      { :name               => "health_score", 
        :label              => "Health score"},

      { :name               => "account_tier", 
        :label              => "Account tier" },

      { :name               => "renewal_date", 
        :label              => "Renewal date" },

      { :name               => "industry", 
        :label              => "Industry" }
    ]

  def populate_tam_fields_data
    begin
      company_fields_data(account).each do |field_data|
        field_name = field_data.delete(:name)
        column_name = field_data.delete(:column_name)
        deleted = field_data.delete(:deleted)
        unless field_name == "renewal_date"
          field_data[:custom_field_choices_attributes] = TAM_FIELDS_DATA["#{field_name}_data"]
        end
        field = CompanyField.new(field_data)
        field.name = field_name
        field.column_name = column_name
        field.deleted = deleted
        field.company_form_id = account.company_form.id
        field.save
      end
    rescue => e
      Rails.logger.info("Something went wrong while adding the CSM default fields")
      NewRelic::Agent.notice_error(e)
      raise e
    ensure
      account.company_form.clear_cache
    end
  end

  def account
    Account.current
  end

  def company_fields_data account
    existing_fields_count = account.company_form.fields.length
    DEFAULT_FIELDS.each_with_index.map do |f, i|
      {
        :name               => f[:name],
        :column_name        => 'default',
        :label              => f[:label],
        :deleted            => 0,
        :field_type         => :"default_#{f[:name]}",
        :position           => existing_fields_count + i + 1,
        :required_for_agent => f[:required_for_agent] || 0,
        :field_options      => f[:field_options] || {},
      }
    end
  end
  end
end