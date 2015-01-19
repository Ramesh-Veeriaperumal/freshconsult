# encoding: utf-8
class Helpdesk::CannedResponses::ResponsesController < ApplicationController
  include HelpdeskControllerMethods

  before_filter :load_multiple_items, :only => [:delete_multiple, :update_folder]
  before_filter :load_folders,  :only => [:new, :edit, :create, :update]
  before_filter :load_response, :only => [:edit, :update]
  before_filter :reset_visibility,    :only => [:create, :update]
  before_filter :load_folder,   :only => [:new, :edit, :create, :update]
  before_filter :construct_params, :only => [:create, :update]
  before_filter :set_selected_tab
  before_filter :check_ca_privilege, :only => [:edit, :update]

  def show
    redirect_to edit_helpdesk_canned_responses_folder_response_path
  end

  def new
    @ca_response = scoper.new
    build_ca_response_defaults
    respond_to do |format|
      format.html
      format.xml  { render :xml => @ca_response }
    end
  end

  def edit
    respond_to do |format|
      format.html # edit.html.erb
      format.xml  { render :xml => @ca_response }
    end
  end

  def create
    @ca_response = scoper.build(@data_params[:admin_canned_responses_response])
    build_attachments @ca_response, :admin_canned_responses_response
    respond_to do |format|
      if @ca_response.save
        format.html {redirect_to(helpdesk_canned_responses_folder_path(@folder),
                                 :notice => t('canned_folders.created'))
                     }
        format.xml  { render :xml => @ca_response,
                      :status => :created,
                      :location => @ca_response
                      }
      else
        build_ca_response_defaults
        format.html { render :action => "new" }
        format.xml  { render :xml => @ca_response.errors, :status => :unprocessable_entity }
      end

    end
  end

  def update
    build_attachments @ca_response, :admin_canned_responses_response
    @data_params[:admin_canned_responses_response][:helpdesk_accessible_attributes].merge!(:id => @ca_response.helpdesk_accessible.id)
    delete_shared_attachments params[:id]
    respond_to do |format|
      if @ca_response.update_attributes(@data_params[:admin_canned_responses_response])
        format.html {
          redirect_to(helpdesk_canned_responses_folder_path(@ca_response.folder_id), :notice => t('canned_folders.update'))
        }
        format.xml  {
          render :xml => @ca_response, :status => :updated, :location => @ca_response
        }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @ca_response.errors, :status => :unprocessable_entity }
      end
    end
  end

  def delete_multiple
    @items.each do |item|
      item.destroy if item.visible_to_me?
    end
  end

  def delete_shared_attachments(ca_response)
    if !params[:remove_attachments].nil?
      (params[:remove_attachments].uniq || []).each do |a|
        shared_attachment = Helpdesk::SharedAttachment.find_by_shared_attachable_id(ca_response, :conditions=>["attachment_id=?",a])
        shared_attachment.destroy if shared_attachment
      end
    end
  end

  def update_folder
    old_folder = current_account.canned_response_folders.find_by_id(params[:folder_id])
    new_folder = current_account.canned_response_folders.find_by_id(params[:move_folder_id])
    error_responses = []

    if(!old_folder.nil? && !new_folder.nil?)
      update_hash = { :folder_id => params[:move_folder_id] }
      @items.each do |item|
        group_ids = []
        user_ids = []
        if new_folder.personal?
          access_type = Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]
          user_ids = [current_user.id]
        else
          access_type = params[:visibility] || item.helpdesk_accessible.access_type
          if access_type.to_i == Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups]
            if params[:admin_canned_response]
              group_ids = params[:admin_canned_response][:visibility][:group_id]
            else
              group_ids = item.helpdesk_accessible.group_ids
            end
          elsif access_type.to_i == Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]
            user_ids = [current_user.id]
          end
        end
        update_hash = update_hash.merge(:helpdesk_accessible_attributes => {:id => item.helpdesk_accessible.id, 
          :group_ids => group_ids,
          :user_ids => user_ids,
          :access_type => access_type})
          
        error_responses << item.title if !item.update_attributes(update_hash)
      end

      if error_responses.empty?
        flash[:notice] = t('canned_folders.folder_update',{:folder_name => new_folder.display_name})
      else
        flash[:notice] = t('canned_folders.moved_responses_update',{:responses => error_responses.join(","), :folder_name => new_folder.display_name})
      end
    else
      folder_id = old_folder.nil? ? params[:folder_id] : params[:move_folder_id]
      flash[:notice] = t('canned_folders.folder_validation')
    end

    redirect_to(:back)
  end

  private

  def cname
    @cname ||= controller_name.singularize
  end

  def load_folders
    @all_folders = current_account.canned_response_folders
    @pfolder     = @all_folders.select{|f| f.personal?}.first

    @response_folders = @all_folders.clone
    @response_folders.delete_if{ |folder| folder.id == @pfolder.id }
  end

  def load_response
    @ca_response = scoper.find(params[:id])
  end

  def reset_visibility
    if params[:admin_canned_responses_response][:visibility].nil?
      params[:admin_canned_responses_response].merge!("visibility" => {"visibility" => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users], "user_id" => current_user.id})
    end
    visibility = params[:admin_canned_responses_response][:visibility]
    unless privilege?(:manage_canned_responses)
      visibility[:visibility] = Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]
      visibility[:user_id]    = current_user.id
    end
    params[:new_folder_id] = @pfolder.id if visibility[:visibility].to_i == Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]
  end

  def load_folder
    @folder = @all_folders.select{|x| x.id == params[:folder_id].to_i}.first
    if params[:new_folder_id]
      @folder = @all_folders.select{|x| x.id == params[:new_folder_id].to_i}.first
      params[:admin_canned_responses_response].merge!("folder_id" => params[:new_folder_id])
    end
  end

  #Constructing nested attributes for model to save all its associations.
  def construct_params
    @data_params      =  {}

    admin_ca          = params[:admin_canned_responses_response]
    title             = admin_ca[:title]
    content_html      = admin_ca[:content_html]
    folder_id         = admin_ca[:folder_id]
    access_type       = admin_ca[:visibility][:visibility]
    group_ids         = []
    user_ids          = []

    if access_type.to_i == Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups]
      group_ids = admin_ca[:visibility][:group_id]
    elsif access_type.to_i == Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]
      user_ids = [admin_ca[:visibility][:user_id]]
    end

    @data_params = {
      :admin_canned_responses_response => {
                                           :title => title, :content_html => content_html,
            :helpdesk_accessible_attributes => {
                                                  :user_ids => user_ids, :group_ids => group_ids, :access_type => access_type
                                                }, 
                                                  :folder_id => folder_id
                                          }
                    }

  end

  def default_response_params
    {
      "visibility" => {
        "user_id"     =>  current_user.id,
        "visibility"  =>  Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users],
        "group_id"    =>  ""
      }
    }
  end

  def scoper
    current_account.canned_responses
  end

  def set_selected_tab
    @selected_tab = :admin
  end

  def build_ca_response_defaults
    @ca_response.helpdesk_accessible = current_account.accesses.new
    @ca_response.helpdesk_accessible.access_type = @folder.personal? ? 
      Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users] : Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
  end

  def check_ca_privilege
    redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) unless @ca_response.visible_to_me?
  end

end
