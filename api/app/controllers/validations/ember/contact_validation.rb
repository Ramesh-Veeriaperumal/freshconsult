class Ember::ContactValidation < ContactValidation

  attr_accessor :company

  def check_duplicates_multiple_companies
    ids = other_companies.collect{|x| x[:id]}.compact
    if company && ids.any?{|id| id == company[:id]}
      errors[:other_companies] << :cant_add_primary_resource_to_others
      self.error_options.merge!(other_companies: {
        resource: "#{company[:id]}",
        status: "default company",
        attribute: 'other_companies'
      })
    elsif ids.length != ids.uniq.length
      errors[:other_companies] << :duplicate_companies
    end
  end

  def check_for_default_company_before_adding_other_companies
    other_companies && !other_companies.empty? && company.blank?
  end

  def other_companies_format
     {
      id: {
        custom_numericality: {
          ignore_string: :allow_string_param,
          greater_than: 0,
          only_integer: true,
          allow_nil: true
        }
      },
      name: {
        data_type: { rules: String, required: true },
        custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
      },
      view_all_tickets: {
        data_type: {
          rules: 'Boolean',
          ignore_string: :allow_string_param
        }
      }
    }
  end

  def view_all_tickets_present?
    false
  end

end
