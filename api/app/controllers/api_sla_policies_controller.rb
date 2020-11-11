class ApiSlaPoliciesController < ApiApplicationController
  before_filter(except: [:index, :show]) { |c| c.requires_this_feature :sla_management_v2 }
  decorate_views(decorate_objects: [:index], decorate_object: [:create, :update])

  def index
    super
    response.api_meta = { count: @items_count, active_rules: scoper.active.count }
  end

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
      render_201_with_location(location_url: 'sla_policies_url')
    else
      render_custom_errors(@item)
    end
  end

  private
    def after_load_object
      render_request_error(:cannot_update_default_sla, 400) if @item.is_default
    end

    def assign_protected
      "#{constants_class}::SLA_POLICY_PARAMS".constantize.each do |field|
        @item[field] = params[cname][field] if params[cname].has_key?(field)
      end
      @item.conditions = ActiveSupport::HashWithIndifferentAccess.new unless action_name == 'update' && !params[cname].has_key?(:applicable_to)
      escalations_hash = { reminder_response: {}, reminder_resolution: {}, response: {}, resolution: {} }
      escalations_hash.merge!(reminder_next_response: {}, next_response: {}) if current_account.next_response_sla_enabled?
      @item.escalations = ActiveSupport::HashWithIndifferentAccess.new(escalations_hash) unless action_name == 'update' && !params[cname].key?(:escalation)
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
      params[cname].permit(*(allowed_param_fields))
      sla_policy = ApiSlaPolicyValidation.new(params[cname], @item)
      render_errors sla_policy.errors, sla_policy.error_options unless sla_policy.valid?(action_name.to_sym)
    end

    def allowed_param_fields
      "#{constants_class}::#{action_name.upcase}_FIELDS".constantize
    end

    def scoper
      current_account.sla_policies
    end

    def load_objects(items = scoper)
      super items.preload(:sla_details)
    end

    def update_escalation
      SlaPolicyConstants::ESCALATION_TYPES_EXCEPT_RESOLUTION.each do |escalation_type|
        next if ['reminder_next_response', 'next_response'].include?(escalation_type) && !Account.current.next_response_sla_enabled?
        @item.escalations[escalation_type.to_sym]['1'] = tranform_escalation_keys(params[cname][:escalation][escalation_type.to_sym]) if params[cname][:escalation][escalation_type.to_sym].present?
      end
      
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
      sla_detail[:next_response_time] = sla_target[:next_respond_within]
      sla_detail[:resolution_time] = sla_target[:resolve_within] 
      sla_detail[:override_bhrs] = !sla_target[:business_hours] 
      sla_detail[:escalation_enabled] = sla_target[:escalation_enabled] 
      @item.sla_details.build(sla_detail) if action_name.eql?("create")
    end

    def set_custom_errors(item = @item)
      ErrorHelper.rename_error_message(SlaPolicyConstants::FIELD_ERROR_MAPPINGS, item)
      @error_options = { policy_name: item.name }
    end
end
