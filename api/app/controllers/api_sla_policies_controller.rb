class ApiSlaPoliciesController < ApiApplicationController
  def update
    assign_protected
    sla_policy_delegator = SlaPolicyDelegator.new(@item,{:params => params[cname]})
    if !sla_policy_delegator.valid?
      render_errors(sla_policy_delegator.errors, sla_policy_delegator.error_options)
    elsif !@item.save
      render_errors(@item.errors) # not_tested
    end
  end

  def create
    assign_protected
    sla_policy_delegator = SlaPolicyDelegator.new(@item,{:params => params[cname]})
    if sla_policy_delegator.invalid?
      render_errors(sla_policy_delegator.errors, sla_policy_delegator.error_options)
    elsif @item.save
      render_201_with_location(location_url: 'sla_policies_url',item_id: @item.id)
    else
      render_errors(@item.errors)
    end
  end

  private
    def after_load_object
      render_request_error(:cannot_update_default_sla, 400) if @item.is_default
    end

    def assign_protected
      SlaPolicyConstants::SLA_POLICY_PARAMS.each do |field|
        @item[field] = params[cname][field] if params[cname].has_key?(field)
      end
      @item.conditions = ActiveSupport::HashWithIndifferentAccess.new unless action_name == 'update' && !params[cname].has_key?(:applicable_to)
      @item.escalations = ActiveSupport::HashWithIndifferentAccess.new(response: {}, resolution: {}) unless action_name == 'update' && !params[cname].has_key?(:escalation)
      @item.sla_details ||= ActiveSupport::HashWithIndifferentAccess.new

      if params[cname].has_key?(:applicable_to)
        SlaPolicyConstants::SLA_CONDITION.each do |key,value|
          value = params[cname][:applicable_to][key.to_s.pluralize]
          @item.conditions[key] = value.uniq.compact if value.present?
        end
      end
      update_escalation if params[cname].has_key?(:escalation)
      update_sla_target if params[cname].has_key?(:sla_target)
    end

    def constants_class
      :SlaPolicyConstants.to_s.freeze
    end

    def validate_params
      allowed_fields = "#{constants_class}::#{action_name.upcase}_FIELDS".constantize
      params[cname].permit(*allowed_fields)
      sla_policy = ApiSlaPolicyValidation.new(params[cname], @item)
      render_errors sla_policy.errors, sla_policy.error_options unless sla_policy.valid?(action_name.to_sym)
    end

    def scoper
      current_account.sla_policies
    end

    def load_objects(items = scoper)
      super items.preload(:sla_details)
    end

    def update_escalation
      @item.escalations[:response]["1"] = tranform_escalation_keys(params[cname][:escalation][:response]) if params[cname][:escalation][:response].present?
      
      if params[cname][:escalation][:resolution].present?
        Helpdesk::SlaPolicy::ESCALATION_LEVELS.each do |key,value|
          escalation_params = params[cname][:escalation][:resolution].try(:[],key)
          @item.escalations[:resolution][value.to_s] = tranform_escalation_keys(escalation_params) if escalation_params.present?
        end
      end
    end

    def tranform_escalation_keys(escalations_params)
      escalations = ActiveSupport::HashWithIndifferentAccess.new
      escalations[:time] = escalations_params.try(:[],:escalation_time)
      escalations[:agents_id] = escalations_params.try(:[],:agent_ids)
      escalations
    end

    def update_sla_target
      sla_details = @item.sla_details
      TicketConstants::PRIORITY_KEYS_BY_TOKEN.values.each do |priority|
        target_params = params[cname][:sla_target].try(:[],:"priority_#{priority}")
        if target_params.present?
          sla_detail = sla_details.find{|detail| detail.priority == priority }
          tranform_sla_target_keys(target_params,priority, sla_detail) if target_params.present?
        end
      end
    end

    def tranform_sla_target_keys(sla_target,priority,sla_detail)
      sla_detail = ActiveSupport::HashWithIndifferentAccess.new(priority: priority,name: SlaPolicyConstants::SLA_DETAILS_NAME[priority] )  if action_name.eql?("create")
      sla_detail[:response_time] = sla_target[:respond_within] 
      sla_detail[:resolution_time] = sla_target[:resolve_within] 
      sla_detail[:override_bhrs] = !sla_target[:business_hours] 
      sla_detail[:escalation_enabled] = sla_target[:escalation_enabled] 
      @item.sla_details.build(sla_detail) if action_name.eql?("create")
    end
end
