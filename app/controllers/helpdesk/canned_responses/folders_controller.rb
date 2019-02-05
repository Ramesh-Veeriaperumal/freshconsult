# encoding: utf-8
class Helpdesk::CannedResponses::FoldersController < ApplicationController

  include HelpdeskControllerMethods
  include APIHelperMethods

  before_filter :load_object, :only => [:update, :edit, :show, :destroy]
  before_filter :check_default, :only => [:edit, :destroy, :update]
  before_filter :load_folders, :new_folder, :only => [:index, :show]
  before_filter :set_selected_tab

  def index
    @current_folder = current_account.canned_response_folders.general_folder.first
    @ca_responses   = visible_responses(@current_folder)
    render :index
  end

  def show
    @ca_responses = visible_responses(@current_folder)
    respond_to do |format|
      format.html {
        render :index
      }
      format.js
    end
  end

  def new
    @current_folder = scoper.new
    respond_to do |format|
      format.html {
        if request.xhr?
          render :layout => false
        else
          redirect_to helpdesk_canned_responses_folders_path
        end
      }
      format.xml  { render :xml => @current_folder }
    end
  end

  def create
    @current_folder = scoper.build(params[:admin_canned_responses_folder])
    respond_to do |format|
      if @current_folder.save
        format.html {
          redirect_to(helpdesk_canned_responses_folder_path(@current_folder),
                      :notice => t('canned_folders.folder_created'))
        }
        format.xml  { render :xml => @current_folder,
                      :status => :created,
                      :location => @current_folder }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @current_folder.errors,
                      :status => :unprocessable_entity }
      end
    end
  end

  def edit
    respond_to do |format|
      format.html  # edit.html.erb
      format.xml  { render :xml => @current_folder }
    end
  end

  def update
    respond_to do |format|
      if @current_folder.update_attributes(params[:admin_canned_responses_folder])
        format.html {
          redirect_to(helpdesk_canned_responses_folder_path(@current_folder) ,
                      :notice => t('canned_folders.updated'))
        }
        format.xml  { head :ok }
      else
        format.html {
          redirect_to(helpdesk_canned_responses_folder_path(@current_folder) ,
                      :notice => @current_folder.errors.full_messages.to_s)
        }
      end
    end
  end

  private

  def load_object
    errors = {:errors => []}
    @current_folder = scoper.find_by_id(params[:id])
    if !current_account.personal_canned_response_enabled? && @current_folder.personal?
      errors[:errors] << {:message=> t('canned_responses.errors.invalid_plan'), :error => t('canned_responses.errors.invalid_plan_failed') }
      api_json_responder(errors, 400)
    end
  end    

  def check_default
    if @current_folder.is_default?
      raise t('canned_folders.no_edit')
    end
  end    

  def load_folders
    @pfolder = current_account.canned_response_folders.personal_folder.first
    if privilege?(:manage_canned_responses)
      @ca_res_folders = current_account.canned_response_folders.all
    else
      @ca_res_folders = [@pfolder]
    end
  end

  def visible_responses(folder)
    if privilege?(:manage_canned_responses) and !folder.personal?
      folder.canned_responses
    else
      folder.canned_responses.only_me(current_user)
    end
  end

  def new_folder
    @new_ca_res_folder = scoper.new
  end

  def scoper
    current_account.canned_response_folders
  end

  def set_selected_tab
    @selected_tab = :admin
  end  

  def after_destroy_url
    helpdesk_canned_responses_folders_path
  end
end
