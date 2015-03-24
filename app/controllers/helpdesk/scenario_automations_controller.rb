class Helpdesk::ScenarioAutomationsController < ApplicationController

  before_filter :reset_access_type, :only => [:create,:update]
  before_filter :set_user_ids, :only => [:create,:update]
  before_filter :manage_personal_tab, :only => [:index]

  include ModelControllerMethods

  before_filter :escape_html_entities_in_json
  before_filter :load_config, :only => [:new, :edit, :clone_rule]
  before_filter :check_automation_feature
  before_filter :set_selected_tab

  include AutomationControllerMethods
  include HelpdeskAccessMethods


  def index
    @current_tab = params[:current_tab] || default_tab
    cookies[:scenario_show_tab] = @current_tab
    @va_rules = current_tab_shared? ? scoper.all_managed_scenarios(current_user) : scoper.only_me(current_user)
  end

  def new
    @current_tab = cookies[:scenario_show_tab]
    @va_rule.match_type = :all
    default_accessible_values
  end

  def create
    @va_rule.action_data = params[:action_data].blank? ? [] : (ActiveSupport::JSON.decode params[:action_data])
    @va_rule.match_type ||= :all
    set_nested_fields_data @va_rule.action_data if @va_rule.action_data
    if @va_rule.save
      flash[:notice] = t(:'flash.general.create.success', :human_name => human_name)
      flash[:highlight] = dom_id(@va_rule)
      @current_tab = reset_tab
      cookies[:scenario_show_tab] = @current_tab
      redirect_back_or_default "/helpdesk/scenario_automations/tab/#{@current_tab}"
    else
      @current_tab = cookies[:scenario_show_tab]
      default_accessible_values
      load_config
      edit_data
      render :action => 'new'
    end
  end

  def edit
    edit_data
  end

  def update
    reset_user_and_group_ids
    @va_rule.action_data = params[:action_data].blank? ? [] : (ActiveSupport::JSON.decode params[:action_data])
    set_nested_fields_data @va_rule.action_data
    if @va_rule.update_attributes(params[:va_rule])
      flash[:notice] = t(:'flash.general.update.success', :human_name => human_name)
      flash[:highlight] = dom_id(@va_rule)
      @current_tab = reset_tab
      cookies[:scenario_show_tab] = @current_tab
      redirect_back_or_default "/helpdesk/scenario_automations/tab/#{@current_tab}"
    else
      @current_tab = cookies[:scenario_show_tab]
      load_config
      edit_data
      render :action => 'edit'
    end
  end

  def clone_rule
    edit_data
    reset_accessible_attributes
    @va_rule.name = "%s #{@va_rule.name}" % t('dispatch.copy_of')
  end

  protected

  def scoper
    current_account.scn_automations
  end

  def all_scoper
    current_account.scn_automations.global_accessible_for(current_account.id)
  end

  def load_object
    @va_rule  = scoper.find_by_id(params[:id])
    @current_tab = reset_tab
    @obj = @va_rule #Destroy of model-controller-methods needs @obj

    redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) unless check_scn_access_to_me?@va_rule
  end

  def cname
    @cname ||= "scenario_automations"
  end

  def build_object #Some bug with build during new, so moved here from ModelControllerMethods
    @va_rule = params[:va_rule].nil? ? ScenarioAutomation.new : scoper.build(params[:va_rule])
  end

  def human_name
    "scenario"
  end

  def check_automation_feature
    requires_feature :scenario_automations
  end

  def set_selected_tab
    @selected_tab = :admin
  end

  def redirect_url
    @current_tab=cookies[:scenario_show_tab]
      "/helpdesk/scenario_automations/tab/#{@current_tab}"
    end

  def reset_access_type
    unless privilege?(:manage_scenario_automation_rules)
       params[:va_rule][:accessible_attributes]={
                    "access_type" => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]
      }
    end
  end

  def set_user_ids
    accesses = params[:va_rule][:accessible_attributes]
    if (accesses[:access_type].to_i == Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users])
      params[:va_rule][:accessible_attributes]=accesses.merge("user_ids"=> [current_user.id])
    end
  end

  def manage_personal_tab
    if !(privilege?(:manage_scenario_automation_rules)) and params[:current_tab]=="shared"
      redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
    end
  end

  private

  def default_tab
    (privilege?(:manage_scenario_automation_rules)) ? "shared" : "personal"
  end

  def reset_tab
    (@va_rule.accessible.access_type == Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users])? "personal" : "shared"
  end

  def default_accessible_values
    @va_rule.accessible = current_account.accesses.new
    @va_rule.accessible.access_type = current_tab_shared? ?
                                  Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all] :
                                  Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]
  end

  def current_tab_shared?
    (@current_tab == "shared")
  end

  def reset_accessible_attributes
    accessible=@va_rule.accessible
    @new_va_rule = @va_rule.dup
    @new_va_rule.accessible=current_account.accesses.new(:access_type=>accessible.access_type)
    if (accessible.access_type == Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups])
      @new_va_rule.accessible.groups=accessible.groups
    end
    @va_rule=@new_va_rule
  end

  def reset_user_and_group_ids
    access_type=@va_rule.accessible.access_type
    new_access=params[:va_rule][:accessible_attributes]
    if(access_type==Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups] and  access_type!=new_access[:access_type].to_i)
      params[:va_rule][:accessible_attributes]=new_access.merge("group_ids"=>[])
    elsif (access_type==Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users] and  access_type!=new_access[:access_type].to_i)
      params[:va_rule][:accessible_attributes]=new_access.merge("user_ids"=>[])
    end
  end

  def check_scn_access_to_me?(va_rule)
    access = true
    if va_rule
      if (privilege?(:manage_scenario_automation_rules))
        (shared_access?va_rule.accessible or va_rule.visible_to_only_me?)
      else
        va_rule.visible_to_only_me?
      end
    end
  end

  def shared_access?(accessible)
    (accessible.global_access_type? or accessible.group_access_type?)
  end

end
