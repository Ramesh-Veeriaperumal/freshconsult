class Admin::ApiSkillsController < ApiApplicationController
  include HelperConcern
  include Admin::SkillHelper
  include Admin::CustomFieldHelper
  include Admin::SkillConstants

  before_filter :reorder_from_api, only: [:update], if: :position_changed?

  decorate_views(decorate_objects: [:index])

  def index
    super
    response.api_meta = { count: @items_count, next_page: @more_items }
  end

  def create
    assign_protected
    skill_delegator = skill_delegator_class.new(@item, params[cname], action_name.to_sym)
    if skill_delegator.invalid?(action_name.to_sym)
      render_custom_errors(skill_delegator, true)
    elsif @item.save
      render_201_with_location
    end
  end

  def update
    assign_protected
    skill_delegator = skill_delegator_class.new(@item, params[cname], action_name.to_sym)
    if skill_delegator.invalid?(action_name.to_sym)
      render_custom_errors(skill_delegator, true)
    elsif !@item.update_attributes(params[cname])
      render_custom_errors
    end
  end

  private

    def scoper
      OBJECT_FROM_DB_ACTIONS.include?(action_name.to_sym) ? current_account.skills : current_account.skills_from_cache
    end

    def load_object(items = scoper)
      @item = items.find { |skill| skill.id == params[:id].to_i } unless items.nil?
      log_and_render_404 unless @item
    end

    def assign_protected
      skill_params = cname_params
      @name = skill_params[:name]
      @agents = skill_params[:agents]
      @rank = skill_params[:rank]
      @match_type = skill_params[:match_type]
      @conditions = skill_params[:conditions]
      set_skill_fields
    end

    def validate_params
      if params[cname].blank?
        render_errors([[:payload, :invalid_json]])
      else
        skill_validation = skill_validation_class.new(params, custom_field_hash, agent_user_ids)
        if skill_validation.invalid?(action_name.to_sym)
          render_errors(skill_validation.errors, skill_validation.error_options)
        else
          check_skill_condition_params
        end
      end
    end

    def custom_field_hash
      ticket_fields_condition_hash = custom_condition_ticket_field[1].select { |field| TICKET_CUSTOM_FIELD_TYPES.include? field[:field_type] }
      contact_fields_condition_hash = custom_condition_contact[1].select { |field| CUSTOMER_CUSTOM_FIELD_TYPES.include? field[:field_type] }
      company_fields_condition_hash = custom_condition_company[1].select { |field| CUSTOMER_CUSTOM_FIELD_TYPES.include? field[:field_type] }
      { ticket: [ticket_fields_condition_hash.map { |field_hash| field_hash[:name] }, ticket_fields_condition_hash],
        contact: [contact_fields_condition_hash.map { |field_hash| field_hash[:name] }, contact_fields_condition_hash],
        company: [company_fields_condition_hash.map { |field_hash| field_hash[:name] }, company_fields_condition_hash] }
    end

    def render_201_with_location
      render "#{controller_path}/#{action_name}", status: 201
    end

    def position_changed?
      params[cname].key?(:rank)
    end

    def reorder_from_api
      @item.position_changes = [@item.position, params[cname][:rank]]
    end

    def skill_validation_class
      'Admin::SkillValidation'.constantize
    end

    def skill_delegator_class
      'Admin::SkillDelegator'.constantize
    end
end