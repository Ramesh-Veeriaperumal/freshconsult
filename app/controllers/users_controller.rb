class UsersController < ApplicationController 

  include ModelControllerMethods #Need to remove this, all we need is only show.. by Shan. to do must!
  include HelpdeskControllerMethods
  include ApplicationHelper
  include ActionView::Helpers::TagHelper, ActionView::Helpers::TextHelper
  # include ActionView::Helpers::AssetTagHelper
  # include ActionView::AssetPaths

  skip_before_filter :check_privilege, :verify_authenticity_token,
                     :only => [:revert_identity, :profile_image,
                               :profile_image_no_blank, :enable_falcon, :disable_falcon,
                               :accept_gdpr_compliance, :enable_undo_send,
                               :disable_undo_send, :set_conversation_preference, :change_focus_mode]
  before_filter :set_ui_preference, :only => [:show]
  before_filter :set_selected_tab
  skip_before_filter :load_object , :only => [ :show, :edit ]
  before_filter(:only => [:assume_identity]) { |c| c.requires_this_feature :assume_identity }
  before_filter :assume_allowed?, :only => [:assume_identity]
  before_filter :load_items, :only => :block
  before_filter :has_access_to_enable_falcon?, :only => [:enable_falcon_for_all]
  before_filter :has_access_to_disable_old_ui?, :only => [:disable_old_helpdesk]
  before_filter :req_feature, :only => [:set_conversation_preference]

  ##redirect to contacts
  def index
    redirect_to contacts_url
  end
    
  def new
    redirect_to new_contact_url
  end
  
  def edit
    redirect_to edit_contact_url
  end

  def me
    headers['Access-Control-Allow-Origin']   = '*'
    headers['Access-Control-Allow-Methods']  = 'GET'
    headers['Access-Control-Request-Method'] = 'GET'
    headers['Access-Control-Allow-Headers']  = 'Origin, X-Requested-With, Content-Type, Accept, Authorization'

    aes = OpenSSL::Cipher::Cipher.new('aes-256-cbc')
    aes.encrypt
    aes.key = Digest::SHA256.digest(ChromeExtensionConfig["key"]) 
    aes.iv  = ChromeExtensionConfig["iv"]

    account_data = {
      :account_id => current_user.account_id, 
      :user_id    => current_user.id
    }.to_json
    encoded_data = Base64.encode64(aes.update(account_data)+ aes.final)
    render :json => {:data => encoded_data}.to_json
  end
  
  def create    
    @user = current_account.users.new #by Shan need to check later       
    if @user.signup!(params)
      #@user.deliver_activation_instructions! #Have moved it to signup! method in the model itself.
      flash[:notice] = t("user_activation_message_sent", :user_email => @user.email)
      redirect_to users_url
    else
      render :action => :new
    end
  end
  
  def block
    @items.each do |item|
      item.deleted = true 
      item.save if item.customer?
    end
    flash[:notice] = t("users_blocked_message", :users => @items.map {|u| u.name}.join(', '))
    render(:update) { |page| show_ajax_flash(page)  }
  end
  
   
  def show
    logger.debug "in users controller :: show show"
    user = current_account.all_users.find(params[:id])        
    if(user.customer? )
      redirect_to :controller =>'contacts' ,:action => 'show', :id => params[:id], :format => params[:format]
    else    
      redirect_to controller: 'agents', action: 'show', id: params[:id], format: params[:format]
    end
    
  end

  def profile_image
    load_object
    redirect_to (@user.avatar.nil? ? "/images/misc/profile_blank_thumb.jpg" : 
      @user.avatar.expiring_url(:thumb, 300))
  end

  def profile_image_no_blank
    load_object
    if @user.avatar.present?
      redirect_to @user.avatar.expiring_url(:thumb, 300)
    elsif is_user_social(@user, 300).present?
      redirect_to is_user_social(@user, 300)
    else
      render :text => "noimage"
    end
  end

  def delete_avatar
    load_object
    @user.avatar.destroy
    render :text => "success"
  end
  
  def assume_identity
    user = current_account.users.find params[:id]

    if assume_identity_for_user(user)
      flash[:notice] = I18n.t("assumed_identity_msg", :user_name => user.name)
    else
      flash[:notice] = I18n.t("assuming_identity_not_allowed_msg")
    end
    redirect_to "/"
  end

  def assumable_agents
    assumable_agents = current_user.agent.assumable_agents.inject([]) do |result, agent|
      result  <<  {id: "#{agent.id}", value: "#{agent.name}", text: "#{agent.name}"}
    end

    respond_to do |format|
      format.json { render :json => assumable_agents }
    end
  end

  def revert_identity
    if(session.has_key?(:original_user))
      
      revert_current_user

      session.delete :original_user
      session.delete :assumed_user
      
      flash[:notice] = I18n.t("identity_reverted_msg")
    else
      flash[:error] = I18n.t("identity_reverted_error_msg")
    end
    redirect_to "/"
  end

  def enable_falcon
    return unless current_account.falcon_ui_enabled?
    current_user.toggle_ui_preference unless current_user.is_falcon_pref?
    cookies[:falcon_enabled] = true
    redirect_to_falcon
  end

  def disable_falcon
    # render nothing: true, status: 400 unless get_referer.start_with?('/a/')
    return head(401) if current_account.disable_old_ui_enabled?
    current_user.disable_falcon_ui if current_user.is_falcon_pref?
    cookies[:falcon_enabled] = false
    return head :no_content
  end

  def enable_falcon_for_all
    current_account.enable_falcon_ui
    Rails.logger.info("Falcon for all :: #{User.current.email} :: #{User.current.id} :: #{Account.current.id}")
    return head :no_content
  end

  def disable_old_helpdesk
    current_account.add_feature(:disable_old_ui)
    Rails.logger.info("Disable OLD UI :: #{User.current.email} :: #{User.current.id} :: #{Account.current.id}")
    return head :no_content
  end

  def accept_gdpr_compliance
    current_user.remove_gdpr_preference
    success = current_user.save
    render :json => {:success => success}
  end

  def enable_undo_send
    head 400 unless current_account.undo_send_enabled?
    current_user.toggle_undo_send(true) unless current_user.enabled_undo_send?
    head :no_content
  end

  def disable_undo_send
    head 400 unless current_account.undo_send_enabled?
    current_user.toggle_undo_send(false) if current_user.enabled_undo_send?
    head :no_content
  end

  def change_focus_mode
    value = params[:value].to_bool rescue false
    current_user.agent.focus_mode = value
    current_user.agent.save
    head :no_content
  end

  def set_conversation_preference
    current_user.set_notes_pref(params[:oldest_on_top]) if current_account.falcon_ui_enabled?(current_user) && params[:oldest_on_top].present?
    head :no_content
  end

  protected
  
    def scoper
      current_account.all_users
    end

    def load_item
      @user = @item = scoper.find(params[:id])

      @item || raise(ActiveRecord::RecordNotFound)
    end
    

    def set_selected_tab
      @selected_tab = :customers
    end

    def assume_allowed?
      redirect_to safe_send(Helpdesk::ACCESS_DENIED_ROUTE) if current_account.hide_agent_metrics_feature?
    end

    def redirect_to_falcon
      options = {
        prevent_redirect: false,
        request_referer: request.referer,
        path_info: request.path_info,
        controller: self.class.name,
        action: request.params[:action],
        domain: request.domain
      }
      redirect_to FalconRedirection.falcon_redirect(options)[:path]
    end

    def check_re_routes
      get_re_route(req_referer)
    end

    def has_access_to_enable_falcon?
      return head(403) if current_account.falcon_enabled?
    end

    def has_access_to_disable_old_ui?
      return head(401) unless current_account.falcon_enabled?
      return head(403) if current_account.disable_old_ui_enabled?
    end

    def req_feature
      if !current_account.reverse_notes_enabled? || current_user.customer?
        return head(401)
      end
    end
end
