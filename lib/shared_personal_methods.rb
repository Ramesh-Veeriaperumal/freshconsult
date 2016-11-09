module SharedPersonalMethods

  ALLOWED_TABS = ["shared", "personal"]

  def self.included(base)
    base.class_eval {
      before_filter :reset_access_type,         :only => [:create, :update]
      around_filter :run_on_slave,              :only => [:index]
      before_filter :manage_personal_tab,       :only => [:index]
      before_filter :set_selected_tab
      before_filter :build_item,                :only => [:new, :new_child, :create, :apply_existing_child, :verify_template_name]
      before_filter :load_item,                 :only => [:edit, :edit_child, :update, :clone, :destroy, :unlink_parent, :add_existing_child]
      before_filter :reset_user_and_group_ids,  :only => :update
    }
  end

  def index
    @current_tab = params[:current_tab] || default_tab
    cookies[:"#{human_name}_show_tab"] = @current_tab
    @order_by = params[:recently_created] ? "created_at desc" : "name"
    @per_page =  ((params[:per_page].blank? || params[:per_page].to_i.zero? || params[:per_page].to_i > 15) ?
      15 :  params[:per_page])
    @page = params[:page].to_i.zero? ? nil : params[:page]
    @all_items = if current_tab_shared?
      scoper.send("shared_#{human_name.pluralize}", current_user).order(@order_by).paginate(:per_page =>
        @per_page, :page => @page)
    else
      scoper.only_me(current_user).order(@order_by).paginate(:per_page => @per_page, :page => @page)
    end
  end

  def new
    @current_tab = cookies[:"#{human_name}_show_tab"]
    default_accessible_values
  end

  def destroy
    result = @item.destroy ? "success" : "failure"
    flash[:notice] = I18n.t(:"flash.general.destroy.#{result}", :human_name => human_name)
    @current_tab   = cookies[:"#{human_name}_show_tab"]
    redirect_back_or_default redirect_url
  end

  protected

  def render *args
    initialize_variable if @item.present?
    super
  end

  def run_on_slave(&block)
    Sharding.run_on_slave(&block)
  end

  private

  def load_item
    @item = scoper.find_by_id(params[:id])
    if verify_access?(@item)
      @current_tab = reset_tab
    else
      redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
    end
  end

  def manage_personal_tab
    if (params[:current_tab] and !ALLOWED_TABS.include?(params[:current_tab])) or
        (!has_privilege? and params[:current_tab] == "shared")
      redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
    end
  end

  def reset_tab
    (@item.accessible.access_type == Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]) ? "personal" : "shared"
  end

  def default_accessible_values
    @item.accessible = current_account.accesses.new
    @item.accessible.access_type = current_tab_shared? ? Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all] :
      Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]
  end

  def verify_access?(item)
    item.visible_to_only_me? || (has_privilege? and shared_access?(item.accessible)) if item
  end

  def shared_access?(accessible)
    accessible.global_access_type? or accessible.group_access_type?
  end

  def reset_access_type
    unless has_privilege?
      params[module_type][:accessible_attributes] = {
        "access_type" => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]
      }
    end
    accesses = params[module_type][:accessible_attributes]
    if (accesses[:access_type].to_i == Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users])
      params[module_type][:accessible_attributes] = accesses.merge("user_ids" => [current_user.id])
    end
  end

  def reset_user_and_group_ids
    access_type = @item.accessible.access_type
    new_access  = params[module_type][:accessible_attributes]
    if(access_type == Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups] and access_type != new_access[:access_type].to_i)
      params[module_type][:accessible_attributes] = new_access.merge("group_ids" => [])
    elsif (access_type == Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users] and access_type != new_access[:access_type].to_i)
      params[module_type][:accessible_attributes] = new_access.merge("user_ids" => [])
    end
  end

  def after_upsert action
    flash[:notice]    = t(:"flash.general.#{action}.success", :human_name => human_name)
    flash[:highlight] = dom_id(@item)
    @current_tab      = reset_tab
    cookies[:"#{human_name}_show_tab"] = @current_tab
    redirect_back_or_default redirect_url
  end

  def clone_attributes
    accessible = @item.accessible
    new_item   = @item.dup
    new_item.accessible = current_account.accesses.new(:access_type => accessible.access_type)
    if (accessible.access_type == Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups])
      new_item.accessible.groups = accessible.groups
    end
    @item = new_item
  end

  def default_tab
    has_privilege? ? "shared" : "personal"
  end

  def set_selected_tab
    @selected_tab = :admin
  end

  def current_tab_shared?
    @current_tab == "shared"
  end
end