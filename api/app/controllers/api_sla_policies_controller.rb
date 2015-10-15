class ApiSlaPoliciesController < ApiApplicationController
  def update
    assign_protected
    sla_policy_delegator = SlaPolicyDelegator.new(@item)
    if !sla_policy_delegator.valid?
      render_errors(sla_policy_delegator.errors, sla_policy_delegator.error_options)
    elsif !@item.save
      render_errors(@item.errors) # not_tested
    end
  end

  private

    def after_load_object
      render_request_error(:cannot_update_default_sla, 400) if @item.is_default
    end

    def assign_protected
      if params[cname][:applicable_to][:company_ids].present?
        @item.conditions[:company_id] = params[cname][:applicable_to][:company_ids].uniq.compact
      else
        @item.conditions.delete(:company_id)
      end
    end

    def validate_params
      params[cname].permit(*(SlaPolicyConstants::UPDATE_FIELDS))
      sla_policy = ApiSlaPolicyValidation.new(params[cname], @item)
      render_errors sla_policy.errors, sla_policy.error_options unless sla_policy.valid?
    end

    def scoper
      current_account.sla_policies
    end

    def complex_fields_has_nil?
      json_request? && params[cname].present?
    end

end
