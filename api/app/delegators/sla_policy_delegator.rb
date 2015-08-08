class SlaPolicyDelegator < SimpleDelegator
  include ActiveModel::Validations

  attr_accessor :error_options, :company_ids

  validate :valid_company?, if: -> { !conditions[:company_id].nil? }

  validate :valid_conditions?, if: -> { conditions[:company_ids].nil? }

  def valid_company?
    company_ids = conditions[:company_id]
    invalid_company_ids = company_ids - Account.current.companies_from_cache.map(&:id)
    if invalid_company_ids.present?
      errors.add(:company_ids, 'list is invalid')
      @error_options = { company_ids: { list: "#{invalid_company_ids.join(', ')}" } }
    end
  end

  def valid_conditions?
    errors.add(:conditions, "can't be blank") if conditions.empty?
  end
end
