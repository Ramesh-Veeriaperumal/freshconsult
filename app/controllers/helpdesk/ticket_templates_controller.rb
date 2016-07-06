class Helpdesk::TicketTemplatesController < ApplicationController

  # Hiding personal templates(for time being)
  before_filter :access_denied, :unless => :has_privilege?
  before_filter :delimit_personal, :only => [:index]
  before_filter :restrict_only_me, :only => [:create, :update]
  # Ends here...

  before_filter :template_limit_reached?, :only => [:new, :create, :clone]
  before_filter :reset_params_struct, :only => [:create, :update]

  include HelpdeskControllerMethods
  include SharedPersonalMethods

  before_filter :construct_attachments, :assign_data, :only => [:create, :update]
  before_filter :assign_attachemnts, :only => :clone

  def create
    if @item.save
      after_upsert("create")
    else
      @current_tab = cookies[:template_show_tab]
      default_accessible_values
      render :action => 'new'
    end
  end

  def update
    if @item.update_attributes(params[:helpdesk_ticket_template])
      after_upsert("update")
    else
      @current_tab = cookies[:template_show_tab]
      render :action => 'edit'
    end
  end

  def clone
    clone_attributes
    @item.name = "#{I18n.t('ticket_templates.copy_of')} #{@item.name}"
  end

  def delete_multiple
    @err_tpl_ids = []
    @items.each do |template|
      begin
        verify_access?(template) ? template.destroy : @err_tpl_ids << template.id
      rescue => e
        Rails.logger.error "Exception Message :: #{e.message}"
        @err_tpl_ids << template.id
      end
    end
  end

  protected

  def scoper
    current_account.ticket_templates
  end

  def nscname
    "template_data"
  end

  def build_item
    @item ||= scoper.new
    @item.attributes = params[:helpdesk_ticket_template]
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

  def redirect_url
    "/helpdesk/ticket_templates/tab/#{@current_tab}"
  end

  def template_limit_reached?
    redirect_to(helpdesk_ticket_templates_path) if templates_count_from_cache >= Helpdesk::TicketTemplate::TOTAL_SHARED_TEMPLATES
  end

  def reset_params_struct
    @template_data_params = params[:template_data]
    [:ticket_body_attributes, :custom_field].each do |attrs|
      if @template_data_params.keys.include? "#{attrs}"
        @template_data_params.merge!(@template_data_params[attrs])
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
    @item.data_description_html = @template_data_params[:description_html]
    @item.template_data = (@template_data_params.present? ?
      @item.sanitize_template_data(@template_data_params) : @template_data_params)
  end

  # Hiding personal templates(for time being)
  def delimit_personal
    access_denied if params[:current_tab] == "personal"
  end

  def restrict_only_me
    accesses = params[module_type][:accessible_attributes]
    access_denied if (accesses[:access_type].to_i == Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users])
  end

  def current_tab_shared?
    "shared"
  end
  # Ends here...
end