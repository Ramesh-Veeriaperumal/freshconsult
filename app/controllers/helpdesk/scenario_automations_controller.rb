class Helpdesk::ScenarioAutomationsController < ApplicationController

  include AutomationControllerMethods
  include SharedPersonalMethods

  before_filter :escape_html_entities_in_json
  before_filter :load_config, :only => [:new, :edit, :clone]
  before_filter :set_type,    :only => :new
  before_filter :validate_email_template, :only => [:create, :update]

  def create
    @item.action_data = params[:action_data].blank? ? [] : (ActiveSupport::JSON.decode params[:action_data])
    @item.match_type ||= :all
    set_nested_fields_data @item.action_data if @item.action_data
    if @item.save
      after_upsert("create")
    else
      @current_tab = cookies[:scenario_show_tab]
      default_accessible_values
      load_config
      edit_info
      render :action => 'new'
    end
  end

  def update
    @item.action_data = params[:action_data].blank? ? [] : (ActiveSupport::JSON.decode params[:action_data])
    set_nested_fields_data @item.action_data
    if @item.update_attributes(params[:va_rule])
      after_upsert("update")
    else
      @current_tab = cookies[:scenario_show_tab]
      load_config
      edit_info
      render :action => 'edit'
    end
  end

  def edit
    edit_info
  end

  def clone
    edit_info
    clone_attributes
    @item.name = "#{I18n.t('dispatch.copy_of')} #{@item.name}"
  end

  protected

  def scoper
    current_account.scn_automations
  end

  def cname
    @cname ||= "scenario_automations"
  end

  def build_item #Some bug with build during new, so moved here from ModelControllerMethods
    @item = params[:va_rule].nil? ? ScenarioAutomation.new : scoper.build(params[:va_rule])
  end

  def human_name
    "scenario"
  end

  def has_privilege?
    privilege?(:manage_scenario_automation_rules)
  end

  def module_type
    @type ||= :va_rule
  end

  def initialize_variable
    @va_rule = @item
  end

  def redirect_url
    "/helpdesk/scenario_automations/tab/#{@current_tab}"
  end

  def set_type
    @item.match_type = :all
  end

  def edit_info
    edit_data @item
  end
end
