# encoding: utf-8
class Helpdesk::CannedResponses::ResponsesController < ApplicationController
  include HelpdeskControllerMethods
  include AccessibleControllerMethods

  before_filter :load_multiple_items, :only => [:delete_multiple, :update_folder]
  before_filter :load_folders,  :only => [:new, :edit, :create, :update]
  before_filter :load_response, :only => [:edit, :update]
  before_filter :reset_visibility,    :only => [:create, :update]
  before_filter :load_folder,   :only => [:new, :edit, :create, :update]
  before_filter :set_selected_tab

  def show
    redirect_to edit_helpdesk_canned_responses_folder_response_path
  end

  def new
    @ca_response = scoper.new
    @ca_response.accessible = current_account.user_accesses.new
    @ca_response.accessible.visibility = @folder.personal? ?
      Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me] : Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents]
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
    @ca_response = scoper.build(params[:admin_canned_responses_response])
    build_attachments @ca_response, :admin_canned_responses_response
    respond_to do |format|
      if @ca_response.save
        create_helpdesk_accessible(@ca_response, "admin_canned_responses_response")
        format.html {redirect_to(helpdesk_canned_responses_folder_path(@folder),
                                 :notice => t('canned_folders.created'))
                     }
        format.xml  { render :xml => @ca_response,
                      :status => :created,
                      :location => @ca_response
                      }
      else
        @ca_response.accessible = current_account.user_accesses.new
        @ca_response.accessible.visibility = params[:admin_canned_responses_response][:visibility][:visibility]
        format.html { render :action => "new" }
        format.xml  { render :xml => @ca_response.errors, :status => :unprocessable_entity }
      end

    end
  end

  def update
    build_attachments @ca_response, :admin_canned_responses_response
    delete_shared_attachments params[:id]
    respond_to do |format|
      if @ca_response.update_attributes(params[:admin_canned_responses_response])
        update_helpdesk_accessible(@ca_response, "admin_canned_responses_response")
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
      item.destroy
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
      params[:admin_canned_response] = params[:admin_canned_response] || default_response_params
      update_hash = { :folder_id => params[:move_folder_id] }
      if new_folder.personal? || old_folder.personal?
        visibility = {
          "user_id"    => current_user.id,
          "group_id"   => params[:admin_canned_response][:visibility][:group_id],
          "visibility" => params[:visibility] || Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me]
        }
        params[:admin_canned_response][:visibility] = visibility
        update_hash[:visibility] = visibility
      end

      @items.each do |item|
        if !item.update_attributes(update_hash)
          error_responses << item.title
        else
          if new_folder.personal? || old_folder.personal?
            update_helpdesk_accessible(item, "admin_canned_response")
          end
        end
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
    visibility = params[:admin_canned_responses_response][:visibility]
    unless privilege?(:manage_canned_responses)
      visibility[:visibility] = Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me]
      visibility[:user_id]    = current_user.id
    end
    params[:new_folder_id] = @pfolder.id if visibility[:visibility].to_i == Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me]
  end

  def load_folder
    @folder = @all_folders.select{|x| x.id == params[:folder_id].to_i}.first
    if params[:new_folder_id]
      @folder = @all_folders.select{|x| x.id == params[:new_folder_id].to_i}.first
      params[:admin_canned_responses_response].merge!("folder_id" => params[:new_folder_id])
    end
  end

  def default_response_params
    {
      "visibility" => {
        "user_id"     =>  current_user.id,
        "visibility"  =>  Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me],
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
end
