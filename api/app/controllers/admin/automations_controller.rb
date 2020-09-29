class Admin::AutomationsController < ApiApplicationController
  include Admin::AutomationConstants
  include HelperConcern
  include Admin::AutomationHelper
  include Redis::AutomationRuleRedis
  include AutomationRuleHelper
  include Va::Constants
  include Admin::CustomFieldHelper
  include Admin::EventCustomFieldHelper
  include Admin::ActionCustomFieldHelper

  prepend_before_filter :check_for_allowed_rule_type
  before_filter :check_privilege
  after_filter :response_api_root_key, only: [:index, :create, :show, :update]
  before_filter :fetch_rule_positions_in_ui, only: [:update], if: :position_changed? # re-order

  ROOT_KEY = :rule
  decorate_views(decorate_objects: [:index])

  def index
    super
    fetch_executed_ticket_counts if @items.size > 0
    response.api_meta = {
      count: @items_count,
      cascading_rules: current_account.cascade_dispatcher_enabled?,
      active_rules: scoper.active.count
    }
  end

  def create
    assign_protected
    automation_delegator = automation_delegator_class.new(params, params[cname], params[:rule_type].to_i)
    if automation_delegator.invalid?(action_name.to_sym)
      render_custom_errors(automation_delegator, true)
    elsif params[:preview] || @item.save
      render_201_with_location
    end
  end

  def update
    assign_protected
    automation_delegator = automation_delegator_class.new(params, params[cname], params[:rule_type].to_i)
    if automation_delegator.invalid?(action_name.to_sym)
      render_custom_errors(automation_delegator, true)
    elsif !(params[:preview] || @item.update_attributes(params[cname]))
      render_custom_errors
    end
  end

  protected

    def before_build_object
      @item = scoper.new
    end

  private

    def response_api_root_key
      rule_type = params[:rule_type].to_i
      root_key = PRIVATE_API_ROOT_KEY_MAPPING[rule_type]
      response.api_root_key = params[:action] == 'index' ? root_key.to_s.pluralize : root_key
    end

    def check_for_allowed_rule_type
      rule_name = VAConfig::RULES_BY_ID[params[:rule_type].to_i]
      unless VAConfig::ASSOCIATION_MAPPING.key?(rule_name)
        render_request_error(:rule_type_not_allowed, 404, rule_type: params[:rule_type])
      end
    end

    def assign_protected
      va_rule_params = params[cname]
      @conditions = va_rule_params[:conditions]
      @operator = va_rule_params[:operator]
      @performers = va_rule_params[:performer]
      @events = va_rule_params[:events]
      @actions = va_rule_params[:actions]
      set_automations_fields
      @item.last_updated_by = current_user.id
      @item.active ||= false
      @old_rule_position = @item.position
    end

    def scoper
      rule_type = VAConfig::RULES_BY_ID[params[:rule_type].to_i]
      rule_association = VAConfig::ASSOCIATION_MAPPING[rule_type]
      current_account.safe_send("all_#{rule_association}".to_sym) unless rule_association.nil?
    end

    def load_object(items = scoper)
      @item = items.find_by_id(params[:id]) unless items.nil?
      log_and_render_404 unless @item
    end

    def validate_filter_params(_additional_fields = [])
      super fields_to_validate
    end

    def automation_validation_class
      'Admin::AutomationValidation'.constantize
    end

    def validate_params
      if params[cname].blank?
        render_errors([[:payload, :invalid_json]])
      else
        cf_fields = { custom_ticket_event: custom_event_ticket_field, custom_ticket_action: custom_action_ticket_field,
                      custom_ticket_condition: custom_condition_ticket_field, custom_contact_condition: custom_condition_contact,
                      custom_company_condition: custom_condition_company }
        automation_validation = automation_validation_class.new(params, cf_fields, nil, false)
        if automation_validation.invalid?(params[:action].to_sym)
          render_errors(automation_validation.errors, automation_validation.error_options)
        else
          check_automation_params
        end
      end
    end

    def automation_delegator_class
      'Admin::AutomationRules::AutomationDelegator'.constantize
    end

    def render_201_with_location
      render "#{controller_path}/#{action_name}", status: 201
    end

    def constants_class
      Admin::AutomationConstants.to_s.freeze
    end

    def check_privilege
      success = super
      return unless success
      case VAConfig::RULES_BY_ID[params[:rule_type].to_i]
      when :dispatcher
        render_request_error(:access_denied, 403) unless User.current.privilege?(:manage_dispatch_rules)
      when :observer
        render_request_error(:access_denied, 403) unless current_account.create_observer_enabled? &&
            User.current.privilege?(:manage_dispatch_rules)
      when :supervisor
        render_request_error(:access_denied, 403) unless current_account.supervisor_enabled? &&
            User.current.privilege?(:manage_supervisor_rules)
      when :service_task_dispatcher, :service_task_observer
        render_request_error :access_denied, 403 unless User.current.privilege?(:manage_service_task_automation_rules) &&
          current_account.field_service_management_enabled?
      else
        # For scenario_automation and rest
      end
    end

    def position_changed?
      params[cname].key?(:position)
    end

    def fetch_rule_positions_in_ui
      rule_association = VAConfig::ASSOCIATION_MAPPING[VAConfig::RULES_BY_ID[params[:rule_type].to_i]]
      positions_array = current_account.safe_send(rule_association).pluck(:position)
      old_db_position = @item.position
      new_db_position = positions_array[params[cname][:position] - 1]
      if new_db_position.nil?
        render_request_error(:invalid_position, 403, max_position: positions_array.size + 1)
      else
        params[cname][:position] = new_db_position
        @item.frontend_positions = [positions_array.index(old_db_position) + 1, positions_array.index(new_db_position) + 1]
      end
    end
end
