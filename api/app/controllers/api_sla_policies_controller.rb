class ApiSlaPoliciesController < ApiApplicationController
  def update
    conditions = @item.conditions
    conditions[:company_id] = params[cname][:applicable_to][:company_ids] unless params[cname][:applicable_to][:company_ids].nil?
    conditions.delete(:company_id) if params[cname][:applicable_to].key?(:company_ids) && params[cname][:applicable_to][:company_ids].blank?
    sla_policy_delegator = SlaPolicyDelegator.new(@item)
    if !sla_policy_delegator.valid?
      render_error(sla_policy_delegator.errors, sla_policy_delegator.error_options)
    elsif !@item.save
      render_error(@item.errors)
    end
  end

  private

    def validate_params
      fields = SlaPolicyConstants::SLA_UPDATE_FIELDS
      params[cname].permit(*(fields))
      company = ApiSlaPolicyValidation.new(params[cname], @item)
      render_error company.errors, company.error_options unless company.valid?
    end

    def scoper
      current_account.sla_policies
    end
end
