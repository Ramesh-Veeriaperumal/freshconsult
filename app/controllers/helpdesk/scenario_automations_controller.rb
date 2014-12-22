class Helpdesk::ScenarioAutomationsController < ApplicationController

  include ModelControllerMethods

  before_filter :escape_html_entities_in_json
  before_filter :load_config, :only => [:new, :edit, :clone_rule]
  before_filter :check_automation_feature
  before_filter :set_selected_tab

  include AutomationControllerMethods
  include Helpdesk::ReorderUtility

  def recent
    @id_data = ActiveSupport::JSON.decode params[:ids]
    @ticket = current_account.tickets.find(params[:ticket_id].to_i) unless params[:ticket_id].blank?
    @scenarios = @id_data.collect {|id| scoper.accessible_for(current_user).find(:all, :conditions => { :id => @id_data }).detect {|resp| resp.id == id}}
    @scenarios.delete_if { |x| x == nil }
    respond_to do |format|
      format.html
      format.js {
        render :partial => '?' #need to set the path
      }
    end
  end

  protected

  def scoper
    current_account.scn_automations
  end

  def all_scoper
    current_account.scn_automations
  end

  def cname
    @cname ||= "scenario_automations"
  end

  def build_object #Some bug with build during new, so moved here from ModelControllerMethods
    @va_rule = params[:va_rule].nil? ? ScenarioAutomations.new : scoper.build(params[:va_rule])
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

end
