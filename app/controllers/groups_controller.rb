# encoding: utf-8
class GroupsController < Admin::AdminController
  include GroupsHelper

  before_filter :set_user_role, :only => [:new, :edit, :index]
  before_filter :load_group, :only => [:show, :edit, :update, :destroy, :user_skill_exists]
  before_filter :set_account_skills_present, :only => [:new, :edit]
  before_filter :set_gon_data, :only => :edit
  before_filter :set_capping_limit, :filter_params, :build_attributes, :only => [:create, :update]

  def index
    @groups = scoper.order(:name)
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @groups.to_xml(:except=>:account_id) }
      format.json { render :json => @groups.to_json(:except=>:account_id) }
    end
  end

  def show
    respond_to do |format|
      format.html{ redirect_to :action => 'edit' }
      format.xml  { render :xml => @group.to_xml(:except=>:account_id) }
      format.json { render :json => @group.to_json(:except=>:account_id) }
    end
  end

  def new
    @group = current_account.groups.new
    set_gon_data

     respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @group }
    end
  end

  def edit
    respond_to do |format|
      format.html # edit.html.erb
      format.xml  { render :xml => @group }
    end
  end

  def create
    if @group.save
      respond_to do |format|
        format.html { 
          if params[:redirect_to_skills] == "true"
            redirect_to admin_agent_skills_path(:group_id => @group.id)
          else
            redirect_to(groups_url, :notice => t(:'flash.general.create.success', :human_name => 'Group'))
          end
        }
        format.xml { render :xml => @group.to_xml({:except=>[:account_id]}), :status => :created }
        format.json { render :json => @group.to_json({:except=>[:account_id]}), :status => :created }
      end
     else
      respond_to do |format|
        format.html { 
          set_user_role
          render :action => 'new' }
        format.json {
          result = {:errors => @group.errors.full_messages }
          render :json => result.to_json
        }
        format.xml {
          render :xml => @group.errors
        }
      end
     end
  end

  def update
    respond_to do |format|
      if @group.update_attributes(@filtered_group_params)
        format.html do
          if params[:redirect_to_skills] == "true"
            redirect_to admin_agent_skills_path(:group_id => @group.id)
          else
            redirect_to(groups_url, :notice => t(:'flash.general.update.success', :human_name => 'Group'))
          end
        end
        format.xml do
          head :ok
        end
        format.json do
          (request.xhr?) ? (render :json => {:status => true}) : (head :ok)
        end
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @group.errors, :status => :unprocessable_entity }
        format.json {
          result = {:errors=>@group.errors.full_messages }
          render :json => result.to_json }
      end
    end
  end

  def destroy
    @group.destroy

    respond_to do |format|
      format.html { redirect_to(groups_url) }
      format.xml  { head :ok }
      format.json { head :ok }
    end
  end

  def enable_roundrobin_v2
    success = show_roundrobin_v2_notification? and Role.add_manage_availability_privilege
    flash_text = success ? t('group.enable_success_message') : t('group.enable_failure_message')
    render :json => {:flash_text => flash_text}
  end

  def user_skill_exists
    @user_skill_exists = Sharding.run_on_slave do
      current_account.user_skills.exists?(:user_id => @group.agent_ids)
    end
    render :json => {:user_skill_exists => @user_skill_exists}
  end

  def users_list
    users = []
    group_users = scoper.find_by_id(params[:id]).try(:agents) if params[:id]
    if group_users
      group_users = group_users.order(:name)
      group_users.each do |user|
        users << {:user_id => user.id, :group_ids => user.group_ids}
      end
    end
    render json: users
  end


  protected

  def cname # Possible dead code
    @cname ||= controller_name.singularize
  end

  def nscname
    @nscname ||= controller_path.gsub('/', '_').singularize
  end

  def scoper
    current_user.accessible_groups
  end

  private



    def load_group
      @group = gon.current_group = current_user.accessible_groups.find_by_id(params[:id])
      gon.capping_enabled = @group.capping_enabled?
      gon.escalation_agent = @group.escalate.present? ? @group.escalate.name : ""
      access_denied and return if @group.blank?
      # using gon variable to pass rails-variables directly in js files
    end
  
    def set_user_role
      @is_admin = gon.is_admin = privilege?(:admin_tasks)
    end

    def set_account_skills_present
      gon.account_skills_present = current_account.skills_trimmed_version_from_cache.present?
    end

    def filter_params
      @filtered_group_params = global_access? ? params[nscname] :
          params[nscname].slice(:ticket_assign_type, :toggle_availability, :capping_limit)
    end

    def build_attributes
      @group ||= current_account.groups.new(@filtered_group_params)
      if global_access?
        @group.business_calendar = current_account.business_calendar.find_by_id(@filtered_group_params[:business_calendar])
        @group.build_agent_groups_attributes(@filtered_group_params[:agent_list]) unless @filtered_group_params[:agent_list].nil?
      end
    end

    def set_capping_limit
      params[nscname][:capping_limit] = 0 if params[nscname].has_key?(:capping_enabled) &&
                                             params[nscname][:capping_enabled] == "0"
    end

    def set_gon_data
      gon.selected_agents = agents_in_group(@group)
      gon.capping_feature_enabled = current_account.round_robin_capping_enabled? ||current_account.skill_based_round_robin_enabled?
      # using gon variable to pass rails-variables directly in js files
    end
end
