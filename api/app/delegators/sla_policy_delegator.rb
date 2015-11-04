class SlaPolicyDelegator < SimpleDelegator
  include ActiveModel::Validations

  attr_accessor :error_options

  validate :valid_companies?

  def valid_companies?
    company_ids = conditions[:company_id]
    if company_ids
      invalid_company_ids = company_ids - Account.current.companies.map(&:id)
      if invalid_company_ids.present?
        errors[:company_ids] << :invalid_list
        @error_options = { company_ids: { list: "#{invalid_company_ids.join(', ')}" } }
      end
    else
      errors[:company_ids] << :blank if conditions.empty?
    end
  end
end
