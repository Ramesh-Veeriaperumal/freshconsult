class Helpdesk::TicketTemplatesController < ApplicationController

  # Hiding personal templates(for time being)
  before_filter :access_denied,              :unless => :require_feature_and_priv
  before_filter :delimit_personal,           :only => [:index]
  before_filter :restrict_only_me,           :only => [:create, :update], :unless => :parent_id? # Ends here...
  before_filter :restrict_parent_child,      :only => [:new_child, :edit_child, :all_children, :search_children,
                                                        :unlink_parent, :add_existing_child, :apply_existing_child]
  before_filter :template_limit_reached?,    :only => [:new, :create, :clone], :unless => :parent_id?
  before_filter :child_templ_limit_reached?, :only => [:new_child, :create, :add_existing_child], :if => :parent_id?
  before_filter :reset_params_struct,        :only => [:create, :update]

  include Helpdesk::TicketTemplatesHelper
  include HelpdeskControllerMethods
  include SharedPersonalMethods
  include Helpdesk::Accessible::ElasticSearchMethods

  before_filter :initialize_parent,                   :only => [:edit, :edit_child, :update, :clone, :destroy,
                                                                :unlink_parent, :add_existing_child]
  before_filter :audit_items,                         :only => [:new_child, :edit, :edit_child]
  before_filter :load_child,                          :only => [:new_child, :edit, :edit_child, :clone]
  before_filter :assign_description,                  :only => [:edit, :edit_child]
  before_filter :construct_attachments, :assign_data, :only => [:create, :update]
  before_filter :build_assn_attributes,               :only => [:create], :if => :check_for_parent_child_feature?
  before_filter :assign_attachemnts,                  :only => [:clone]

  def create
    if @item.save
      after_upsert("create")
    else
      @current_tab = cookies[:template_show_tab]
      default_item_values
      default_accessible_values
      action = has_parent ? 'new_child' : 'new'
      render :action => action
    end
  end

  def update
    if @item.update_attributes(params[:helpdesk_ticket_template])
      after_upsert("update")
    else
      @current_tab = cookies[:template_show_tab]
      default_item_values
      action = @item.child_template? ? 'edit_child' : 'edit'
      render :action => action
    end
  end

  def clone
    clone_attributes
    @item.name     = "#{I18n.t('ticket_templates.copy_of')} #{@item.name}"
    flash[:notice] = t(:"ticket_templates.clone_message")
  end

  def new_child
    default_accessible_values
  end

  def all_children
    children = fetch_child_templates(25)
    render :json => { :all_children => children }
  end

  def search_children
    srch_result = accessible_from_esv2("Helpdesk::TicketTemplate",
      {:load => Helpdesk::TicketTemplate::INCLUDE_ASSOCIATIONS_BY_CLASS, :size => 300}, default_visiblity,
      "raw_name", nil, nil, params[:child_ids], [Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:child]])
    srch_result = if srch_result.nil?
      fetch_child_templates
    else
      srch_result.compact!
      result_hash(srch_result)
    end
    render :json => { :all_children => srch_result }
  end

  def unlink_parent
    if @item.child_template? and has_parent
      @item.build_parent_assn_attributes(@parent.id)
      if @item.save
        @parent.update_attributes(association_type:
          Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:general]) if @parent.child_templates_count.zero?
        flash[:notice] = t(:"ticket_templates.success.unlink_parent")
        redirect_to redirect_url and return
      end
    end
    flash[:notice]     = t(:"ticket_templates.failure.unlink_parent")
    redirect_to redirect_url(true)
  end

  def add_existing_child
    if @item and @item.child_template? and !has_parent and load_parent
      @item.build_parent_assn_attributes(@parent.id)
      if @item.save
        @parent.update_attributes(association_type:
          Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:parent]) unless @parent.parent_template?
        flash[:notice] = t(:"ticket_templates.success.add_existing_child")
        render :json => { :success => true, :url => redirect_url } and return
      end
    end
    notice = t(:"ticket_templates.failure.add_existing_child")
    render :json => { :success => true, :msg => notice }
  end

  def apply_existing_child
    @child_template  = scoper(:child).find_by_id(params[:id])
    if @child_template.present? and load_parent
      @item = @child_template
      assign_description
    else
      flash[:notice] = t(:"ticket_templates.not_available")
    end
    respond_to do |format|
      format.js { render :partial => "/helpdesk/ticket_templates/apply_child_template" }
    end
  end

  def verify_template_name
    templ_ids = @item.retrieve_duplication(params[:name],params[:template_id],params[:state]!="edit")
    unless templ_ids.empty?
      status = { :failure => true, :message => I18n.t("ticket_templates.errors.duplicate_title") }
    else
      status = { :failure => false }
    end
    render :json => status
  end

  protected

  def scoper model_name = "ticket"
    condition = []
    if params[:action].eql?("index")
      model_name = "prime"
      #remove this,once done with pc downgrade
      condition  = ["association_type = ?", Helpdesk::TicketTemplate::
        ASSOCIATION_TYPES_KEYS_BY_TOKEN[:general]] unless check_for_parent_child_feature?
    end
    current_account.send("#{model_name}_templates").where(condition)
  end

  def nscname
    "template_data"
  end

  def has_privilege?
    privilege?(:manage_ticket_templates)
  end

  def module_type
    @type ||= :helpdesk_ticket_template
  end

  def human_name
    "template"
  end

  def initialize_variable
    @tkt_template = @item
  end

  def initialize_parent
    if !has_parent and @item.parent_template?
      @parent = @item
    end
  end

  def build_item
    @item ||= scoper.new
    @item.attributes = params[:helpdesk_ticket_template]
    initialize_parent
  end

  def load_child
    unless ["edit_child", "new_child"].exclude?(params[:action]) and !@item.parent_template?
      @children = @parent.child_templates
    end
  end

  def load_parent
    @parent ||= scoper(:prime).find_by_id(params[:p_id]) if parent_id?
  end

  def has_parent
    @has_parent ||= if parent_id?
      @parent = if @item.child_template?
        @item.parent_templates.where(:id => params[:p_id]).first
      else
        load_parent
      end
      !@parent.nil?
    end
  end

  def parent_id?
    @parent_id ||= if check_for_parent_child_feature? && params[:p_id]
      p_id = params[:p_id].to_i
      p_id.present? and !p_id.zero?
    end
  end

  def after_upsert action
    if @item.child_template?
      if @parent.parent_template? or @parent.update_attributes(association_type:
          Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:parent])
        flash[:notice]  = t(:"ticket_templates.child_#{action}.success")
        redirect_back_or_default redirect_url
      else
        @item.destroy
        flash[:notice]  = t(:"ticket_templates.child_#{action}.failure")
        redirect_back_or_default redirect_url
      end
    else
      super(action)
    end
  end

  def redirect_url failed=false
    if params[:add_child]
      parent_id = @item.child_template? ? @parent.id : @item.id
      helpdesk_new_child_template_path(parent_id)
    elsif @item.child_template? and failed
      helpdesk_edit_child_template_path(@parent.id, @item.id)
    elsif @item.child_template? and has_parent
      edit_helpdesk_ticket_template_path(@parent)
    else
      helpdesk_my_ticket_templates_path(@current_tab,:recently_created => true)
    end
  end

  # Hiding personal templates(for time being)
  def current_tab_shared?
    "shared"
  end
  # Ends here...

  private

  def template_limit_reached?
    redirect_to(helpdesk_ticket_templates_path) if templates_count_from_cache >= Helpdesk::TicketTemplate::TOTAL_SHARED_TEMPLATES
  end

  def child_templ_limit_reached?
    if is_children_available.is_a? Integer
      redirect_to(edit_helpdesk_ticket_template_path(params[:p_id]),
        :notice => t(:'ticket_templates.child_limit_reached')) if is_children_available >= Helpdesk::TicketTemplate::TOTAL_CHILD_TEMPLATES
    elsif is_children_available.is_a? String
      redirect_to(helpdesk_ticket_templates_path, :notice => is_children_available)
    end
  end

  def is_children_available
    @child_count ||= if load_parent.nil?
      t(:'ticket_templates.parent_not_available')
    else
      @parent.parent_template? ? @parent.child_templates_count : 0
    end
  end

  def reset_access_type
    if parent_id?
      params[module_type][:accessible_attributes] = {
        "access_type" => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all] }
    else
      super
    end
  end

  def reset_params_struct
    @template_data_params = params[:template_data]
    [:ticket_body_attributes, :custom_field].each do |attrs|
      if @template_data_params.keys.include? "#{attrs}"
        attrs == :custom_field ? @template_data_params.merge!(@template_data_params[attrs]) :
          @data_descp = @template_data_params[attrs][:description_html]
        @template_data_params.delete(attrs)
      end
    end
    cb_names = current_account.ticket_fields.custom_checkbox_fields.map(&:name)
    reset_check_box(@template_data_params,cb_names) if cb_names.present?
    @template_data_params.delete_if {|key, value| value.blank? }
  end

  def reset_check_box data,cb_names
    cb_names.map do |cb_name|
      if data.keys.include?(cb_name)
        data[cb_name] = (data[cb_name] == "1") ? true : false
      end
    end
  end

  def construct_attachments
    fetch_item_attachments if params[:action].eql?("create")
    build_attachments @item, :template_data
    @template_data_params.delete(:attachments)
  end

  def assign_attachemnts
    @all_attachments = @item.all_attachments
    @cloud_files     = @item.cloud_files
  end

  def assign_data
    handle_inherit_parent
    @item.data_description_html = @data_descp
    @item.template_data = (@template_data_params.present? ?
      @item.sanitize_template_data(@template_data_params) : @template_data_params)
  end

  def handle_inherit_parent
    if @template_data_params.keys.include?("inherit_parent")
      inherit_parent = @template_data_params[:inherit_parent]
      if inherit_parent == "all"
        @template_data_params.delete_if {|key, value| key != "inherit_parent" }
      else
        inherit_parent = inherit_parent.split(",").to_a
        inherit_parent.delete_if{|key| inherit_parent << "requester_id" if key =="email"}
        @template_data_params[:inherit_parent] = inherit_parent
      end
    end
  end

  def assign_description
    @item.template_data[:description_html] = @item.data_description_html
  end

  def audit_items
    result = case params[:action]
              when 'edit'
                true  if @item.child_template?
              when 'new_child'
                true if !@parent or @parent.child_template?
              when 'edit_child'
                true if !@item.child_template? or !(@parent and @parent.parent_template?)
              end
    redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) if result
  end

  def build_assn_attributes
    if params[:clone_child_ids] && (ids = ActiveSupport::JSON.decode(params[:clone_child_ids])).present?
      @item.build_child_assn_attributes(ids)
    elsif has_parent
      @item.build_parent_assn_attributes(@parent.id)
    end
  end

  def fetch_child_templates size = 300
    search_string  = params[:search_string]
    excluded_ids   = params[:child_ids]
    condition_hash = []
    condition_hash << ""
    if search_string
      condition_hash[0] = "#{condition_hash[0]} name LIKE ?"
      condition_hash << "%#{search_string}%"
    end

    condition_hash[0] = "#{condition_hash[0]} AND " if search_string and excluded_ids.present?
    if excluded_ids.present?
      condition_hash[0] = "#{condition_hash[0]} id NOT IN (?)"
      condition_hash << excluded_ids
    end
    run_on_slave {
      @all_child_templ = scoper(:child).where(condition_hash).order(:name).limit(size) }
    result_hash(@all_child_templ)
  end

  def result_hash templates
    templates.map { |t| {:name => t.name, :id => t.id} }
  end

  def default_item_values
    unless @item.new_record?
      initialize_parent
      assign_description
    end
    load_child
  end

  def require_feature_and_priv
    current_account.features?(:ticket_templates) && has_privilege?
  end

  # Hiding personal templates(for time being)
  def delimit_personal
    access_denied if params[:current_tab] == "personal"
  end

  def restrict_only_me
    accesses = params[module_type][:accessible_attributes]
    access_denied if (accesses[:access_type].to_i == Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users])
  end
  # Ends here...

  def restrict_parent_child
    access_denied unless check_for_parent_child_feature?
  end
end