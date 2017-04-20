class Reports::ScheduledExportsController < ApplicationController
  include ModelControllerMethods
  include Reports::ScheduledExport::Filters
  include Reports::ScheduledExport::Constants
  include ExportCsvUtil
  include Reports::ScheduledExportsHelper

  RANDOM_NUMBER_RANGE = 10**6

  skip_before_filter :check_privilege, :only => :download_file

  before_filter :check_permission, :set_selected_tab, :except => :download_file
  before_filter :check_feature, :only => [:new, :create, :show, :destroy, :download_file]
  before_filter :load_object, :only => [:show, :destroy, :download_file]
  before_filter :check_download_permission, :only => :download_file
  before_filter :check_schedule_owner_permission, :only => [:show, :destroy]
  before_filter :load_config, :generate_id, :only => :new
  before_filter :set_filter_data, :set_fields_data, :set_type_and_email_recipients, :only => :create
  before_filter :has_activity_export_feature_and_privilege?, :load_activity_export, :only => [:edit_activity, :update_activity]

  def index
    @scheduled_exports = current_account.scheduled_ticket_exports_from_cache
    @scheduled_exports_account_count = @scheduled_exports.count
    @scheduled_max_count = ScheduledTicketExport::MAX_NO_OF_SCHEDULED_EXPORTS_PER_ACCOUNT
    load_activity_export if has_activity_export_feature_and_privilege?

    respond_to do |format|
      format.html { @scheduled_exports } #index.html.erb
    end
  end

  def create
    @scheduled_export.id = params[:scheduled_export][:id]
    if @scheduled_export.save
      flash[:notice] = create_flash
      redirect_back_or_default redirect_url
    else
      edit_data
      render :action => 'new'
    end
  end

  def download_file
    if @scheduled_export.file_exists?(params[:file_name])
      respond_to do |format|
        format.html {
          redirect_to @scheduled_export.export_path(params[:file_name])
        }
        format.json {
          render :json => @scheduled_export.export_path(params[:file_name])
        }
      end
    else
      flash[:notice] = t("helpdesk_reports.ticket_schedule.file_not_#{params[:file_name] ? 'found' : 'created'}")
      redirect_back_or_default redirect_url
    end
  end

  def show
    edit_data
  end

  def edit_activity
    @api_url = ACTIVITY_EXPORT_API % {domain: current_account.domain}
  end

  def update_activity
    if @scheduled_activity_export.update_attributes(params[:scheduled_activity_export])
      flash[:notice] = I18n.t(:'flash.general.update.success', :human_name => human_name)
      redirect_back_or_default redirect_url
    else
      render :action => 'edit_activity'
    end
  end

  protected

    def scoper
      current_account.scheduled_ticket_exports
    end

    def set_filter_data
      @scheduled_export.filter_data = params[:filter_data].blank? ? [] :
                                        ActiveSupport::JSON.decode(params[:filter_data])
      set_nested_fields_data @scheduled_export.filter_data
    end

    def set_fields_data
      @scheduled_export.fields_data = params[:fields_data].blank? ? {} : params[:fields_data].to_hash
    end

    def set_type_and_email_recipients
      @scheduled_export.schedule_details[:delivery_type] = params[:scheduled_export][:schedule_details][:delivery_type].to_i
      email_recipients = params[:scheduled_export][:schedule_details][:email_recipients]
      @scheduled_export.schedule_details[:email_recipients] = email_recipients.blank? ? [] : email_recipients.split(EMAIL_RECIPIENTS_DELIMITTER).map(&:to_i)
    end

    def build_object
      @obj = @scheduled_export = params[:scheduled_export].nil? ? scoper.new() : scoper.build(params[:scheduled_export])
      #create of model-controller-methods needs @obj
    end

    def load_object
      @obj = @scheduled_export = scoper.find(params[:id])
      #Destroy of model-controller-methods needs @obj
    end

    def load_config
      @agents = none_option + agents_list_from_cache
      @groups = none_option + groups_list_from_cache

      load_internal_group_agents if allow_shared_ownership_fields?

      @tag_hash = current_account.tags_from_cache.map do |tag|
        CGI.escapeHTML(tag.name)
      end

      load_requesters

      filter_hash = {}
      filter_hash['ticket'] = ticket_filters

      @filter_defs  = ActiveSupport::JSON.encode filter_hash

      #Allowing only 'is' operator
      operator_types = OPERATOR_TYPES.clone.keys.map{|k| [k, ['is']]}.to_h

      @op_types     = ActiveSupport::JSON.encode operator_types
      @op_list      = ActiveSupport::JSON.encode OPERATOR_LIST
      @op_label     = ActiveSupport::JSON.encode ALTERNATE_LABEL

      @field_hash = {}
      @field_hash[:ticket]  = ticket_export_fields_without_customer || []
      @field_hash[:contact] = customer_export_fields "contact" || []
      @field_hash[:company] = customer_export_fields "company" || []

      load_time_zone
    end

    def generate_id
      @scheduled_export.id = "#{SecureRandom.random_number(RANDOM_NUMBER_RANGE)}#{Time.now.to_i}"
    end

    def edit_data
      load_config

      @filter_input = ActiveSupport::JSON.encode @scheduled_export.filter_data

      EXPORT_FIELD_TYPES.each do |type|
        @field_hash[type.to_sym] = transform_fields_hash(@field_hash[type.to_sym],
                                      @scheduled_export.fields_data[type]) unless @scheduled_export.fields_data[type].nil?
      end
    end

    def load_internal_group_agents
      internal_group_ids = current_account.account_status_groups_from_cache.collect(&:group_id).uniq
      internal_agent_ids = current_account.agent_groups.with_groupids(internal_group_ids).pluck(:user_id).uniq
      @internal_groups   = none_option + groups_list_from_cache.select {|g| internal_group_ids.include?(g[0])}
      @internal_agents   = none_option + agents_list_from_cache.select {|a| internal_agent_ids.include?(a[0])}
    end

    def load_requesters
      return if @scheduled_export.filter_data.blank?
      req_filter = @scheduled_export.filter_data.select{|f| f['name'].eql?('requester_id')}[0]
      return unless req_filter
      req_ids = req_filter["value"]
      reqs = current_account.all_users.where(:id => req_ids)
      @requesters = reqs.inject({}) do |res, u|
        res[u.id] = CGI.escapeHTML(u.name)
        res
      end
      @requesters = ActiveSupport::JSON.encode @requesters
    end

    def load_time_zone
      @user_time_zone_abbr = ActiveSupport::TimeZone.new(User.current.time_zone).now.zone
    end

    def set_selected_tab
      @selected_tab = :reports
    end

    def check_feature
      access_denied unless Account.current.auto_ticket_export_enabled?
    end

    def check_permission
      access_denied unless privilege?(:view_reports) && privilege?(:admin_tasks)
    end

    def check_schedule_owner_permission
      access_denied unless @scheduled_export.user_id == current_user.id
    end

    def check_download_permission
      access_denied unless @scheduled_export.has_api_permission?(current_user.id) || 
        @scheduled_export.has_email_permission?(current_user.id)
    end

    def load_activity_export
      @scheduled_activity_export = current_account.activity_export_from_cache if current_account.activity_export_from_cache.present?
      @scheduled_activity_export ||= current_account.build_activity_export(DEFAULT_ATTRIBUTES)
    end

    def require_feature_and_privilege
      has_activity_export_feature_and_privilege?
    end

    def has_activity_export_feature_and_privilege?
      current_account.ticket_activity_export_enabled? && privilege?(:manage_account)
    end
end
