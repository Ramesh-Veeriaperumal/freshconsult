# encoding: utf-8
class GroupsController < Admin::AdminController
  include GroupsHelper

  before_filter :load_group, :only => [:show, :edit, :update, :destroy]
  before_filter :filter_params, :build_attributes, :only => [:create, :update]

  def index
    @groups = current_user.accessible_groups.order(:name)
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
    @group.agent_ids = agents_data.blank? ? [] : agents_data.split(',');
    if @group.save
      respond_to do |format|
        format.html { redirect_to :action => 'index' }
        format.xml { render :xml => @group.to_xml({:except=>[:account_id]}), :status => :created }
        format.json { render :json => @group.to_json({:except=>[:account_id]}), :status => :created }
      end
     else
      respond_to do |format|
        format.html { render :action => 'new' }
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
          redirect_to(groups_url, :notice => t(:'flash.general.update.success', :human_name => 'Group'))
        end
        format.xml do
          head :ok
        end
        format.json do
          head :ok
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

  protected

  def cname # Possible dead code
    @cname ||= controller_name.singularize
  end

  def nscname
    @nscname ||= controller_path.gsub('/', '_').singularize
  end 

  private

    def load_group
      @group = current_user.accessible_groups.find_by_id(params[:id])
      access_denied and return if @group.blank?
    end

    def filter_params
      @filtered_group_params = global_access? ? params[nscname] :
          params[nscname].slice(:ticket_assign_type, :toggle_availability)
    end

    def build_attributes
      @group ||= current_account.groups.new(@filtered_group_params)
      if global_access?
        @group.business_calendar = current_account.business_calendar.find_by_id(@filtered_group_params[:business_calendar])
        @group.build_agent_groups_attributes(@filtered_group_params[:agent_list]) unless @filtered_group_params[:agent_list].nil?
      end
    end

end
