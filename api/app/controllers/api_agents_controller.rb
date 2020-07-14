class ApiAgentsController < ApiApplicationController
  include Admin::ShiftHelper
  include Admin::ShiftConstants
  include HelperConcern
  include ContactsCompaniesConcern
  include Export::Util
  include BulkApiJobsHelper
  include Freshid::CallbackMethods
  include OmniChannelRouting::Util

  skip_before_filter :check_privilege, only: :revert_identity
  before_filter { |c| c.requires_feature(:omni_agent_availability_dashboard) if current_action?('availability_count') && !current_account.launched?(:omni_agent_availability_dashboard) }
  before_filter :validate_filter_params, only: [:index, :availability_count]
  before_filter :check_gdpr_pending?, only: :complete_gdpr_acceptance
  before_filter :load_data_export, only: [:export_s3_url]
  before_filter :validate_params_for_export, only: [:export]
  before_filter :check_bulk_params_limit, only: %i[create_multiple]
  before_filter :validate_feature, only: [:fetch_availability, :update_availability]
  before_filter :shift_service_request, only: [:fetch_availability, :update_availability]

  SLAVE_ACTIONS = %w[index achievements].freeze

  def index
    if only_omni_channel_availability
      # Request OCR for the agents available for automatic ticket assignment
      query_params = { auto_assignment: true }
      (AgentConstants::AVAILABILITY_PARAMS | [:group_id, :page, :per_page, :order_type]).each do |param|
        query_params[param.to_sym] = params[param.to_sym] if params[param.to_sym].present?
      end
      ocr_path = [OCR_PATHS[:get_agents], query_params.to_query].join('?')
      Rails.logger.debug "GET #{ocr_path}"
      begin
        ocr_response = request_ocr(:admin, :get, ocr_path)
        @parsed_ocr_response = JSON.parse(ocr_response)
      rescue Exception => e
        Rails.logger.info "Exception while fetching agents from OCR :: #{e.inspect}"
        NewRelic::Agent.notice_error(e)
      end
    end
    super
  end

  def check_edit_privilege
    if current_account.freshid_integration_enabled? && !current_account.allow_update_agent_enabled?
      return true if @item.user_changes.key?('email') && freshid_user_details(@item.user.email).blank?

      AgentConstants::RESTRICTED_PARAMS.any? do |key|
        if @item.user_changes.key?(key)
          @item.errors[:base] << :cannot_edit_inaccessible_fields
          return false
        end
      end
    end
    true
  end

  def create
    assign_protected
    return unless validate_delegator(nil, params[cname].slice(*AgentConstants::AGENT_CREATE_DELEGATOR_KEY).merge(agent_delegator_params))

    @user = current_account.users.new
    assign_avatar if params[cname][:avatar_id].present? && @delegator.draft_attachments.present?
    params[:user] = params[cname][:user_attributes]
    check_and_assign_field_agent_roles if Account.current.field_service_management_enabled?
    check_and_assign_skills_for_create if Account.current.skill_based_round_robin_enabled?
    assign_user_attributes
    if @user.signup!({ user: params[:user] }, nil, !Account.current.freshid_integration_enabled?)
      assign_agent_attributes
      if @item.save
        render_201_with_location(location_url: 'agents_url', item_id: @item.id)
      else
        render_errors(@item.errors)
      end
    else
      render_errors(@user.errors)
    end
  end

  def update
    assign_protected
    return unless validate_delegator(@item, params[cname].slice(*AgentConstants::AGENT_UPDATE_DELEGATOR_KEY)
        .merge(agent_delegator_params).merge(ticket_scope: params[:ticket_scope]))

    check_and_assign_skills_for_update if Account.current.skill_based_round_robin_enabled?
    @item.freshcaller_enabled = params[cname][:freshcaller_agent] unless params[cname][:freshcaller_agent].nil?
    @item.freshchat_enabled = params[cname][:freshchat_agent] unless params[cname][:freshchat_agent].nil?
    @item.scoreboard_level_id = params[cname][:agent_level_id] if params[cname][:agent_level_id].present?
    params[cname][:user_attributes].each do |k, v|
      @item.user.safe_send("#{k}=", v)
    end
    @item.user_changes = @item.user.agent.user_changes || {}
    @item.user_changes.merge!(@item.user.changes)
    return render_custom_errors(@item) unless check_edit_privilege

    assign_group_with_contribution_group
    return if @item.update_attributes(params[cname].except(:user_attributes))

    render_custom_errors
  end

  def create_multiple
    @errors = []
    build_default_required_params
    validate_agent_params
    @job_id = request.uuid
    initiate_bulk_job(AgentConstants::BULK_API_JOBS_CLASS, params[cname][:agents], @job_id, action_name)
    @job_link = current_account.bulk_job_url(@job_id)
    render('api_agents/create_multiple', status: 202) unless @errors.present?
  end

  def update_multiple
    @errors = []
    validate_agent_params
    @job_id = request.uuid
    initiate_bulk_job(AgentConstants::BULK_API_JOBS_CLASS, params[cname][:agents], @job_id, action_name)
    @job_link = current_account.bulk_job_url(@job_id)
    render('api_agents/update_multiple', status: 202) unless @errors.present?
  end

  def destroy
    @item.user.make_customer
    head 204
  end

  def export
    csv_header_data = {}
    params[cname][:fields].each do |field|
      csv_header_data.merge!(AgentConstants::FIELD_TO_CSV_HEADER_MAP[field])
    end
    job_id = ExportAgents.perform_async(csv_hash: csv_header_data, user: current_user.id, portal_url: fetch_portal_url, receive_via: params[:response_type])
    if params[:response_type] == AgentConstants::RECEIVE_VIA[0]
      @items = { status: 'generating export' }
    elsif params[:response_type] == AgentConstants::RECEIVE_VIA[1]
      url = "#{request.url}/#{job_id}"
      @items = { href: url }
    end
  end

  def export_s3_url
    resp = fetch_export_details
    @items = if resp[:status] == :completed
               { download_url: resp[:download_url] }
             else
               { status: resp[:status] }
             end
    end

  def complete_gdpr_acceptance
    User.current.remove_gdpr_preference
    User.current.save ? (head 204) : render_errors(gdpr_acceptance: :not_allowed_to_accept_gdpr)
  end

  def enable_undo_send
    head 400 unless current_account.undo_send_enabled?
    api_current_user.toggle_undo_send(true) unless api_current_user.enabled_undo_send?
    head :no_content
  end

  def disable_undo_send
    head 400 unless current_account.undo_send_enabled?
    api_current_user.toggle_undo_send(false) if api_current_user.enabled_undo_send?
    head :no_content
  end

  def validate_agent_params
    params[cname][:agents].each do |agent_params|
      validate_params(agent_params)
    end
  end

  def check_bulk_params_limit
    max_limit = AgentConstants::BULK_API_PARAMS_LIMIT
    if params[cname][:agents].size > max_limit
      render_request_error(:bulk_api_limit_exceed, 400,
                           resource: 'agents', current: params[cname][:canned_responses].size, max: max_limit)
    end
  end

  def search_in_freshworks
    freshdesk_user_data = current_account.user_emails.user_for_email(params[:email].to_s)
    user_hash = fetch_user_data_from_email if current_account.freshid_integration_enabled?
    @item = construct_search_in_freshworks_payload(user_hash, freshdesk_user_data)
  end

  def fetch_availability
    add_root_key_for_availability
  end

  def update_availability
    add_root_key_for_availability
  end

  def availability_count
    group_filter_hash = AgentConstants::AVAILABILITY_COUNT_FIELDS.each_with_object({}) do |filter_key, hash|
      hash[filter_key.to_sym] = params[filter_key] if params[filter_key].present?
    end
    ocr_path = OCR_PATHS[:get_availability_count]
    ocr_path = [ocr_path, group_filter_hash.to_query].join('?') if group_filter_hash.present?
    begin
      ocr_response = request_ocr(:admin, :get, ocr_path)
      Rails.logger.debug "GET #{ocr_path}, response: #{ocr_response.inspect}"
      @availability_count = JSON.parse(ocr_response).try(:[], 'agents_availability_count')
    rescue Exception => e
      Rails.logger.info "Exception while fetching availability count from OCR :: #{e.inspect}"
      NewRelic::Agent.notice_error(e)
    end
    response.api_root_key = :availability_count
  end

  private

    def feature_name
      :omni_channel_routing if current_action?('availability_count')
    end

    def add_root_key_for_availability
      response.api_root_key = AVAILABILITY if private_api? && SUCCESS_CODES.include?(response.status)
    end

    def extended_url(_action, _id)
      (request.path.gsub!('_', 'v1') || request.path.gsub('v2', 'v1')).last(-1)
    end

    def validate_feature
      requires_any_feature FeatureConstants::AGENT_STATUSES, FeatureConstants::OMNI_AGENT_AVAILABILITY_DASHBOARD
    end

    def constants_class
      :AgentConstants.to_s.freeze
    end

    def agent_delegator_params
      agent_params = {}
      agent_params[:attachment_ids] = Array.wrap(params[cname][:avatar_id].to_i) if params[cname][:avatar_id].present?
      agent_params[:action] = action_name
      agent_params
    end

    def build_default_required_params
      params[cname][:agents].each do |agent|
        agent[:name] ||= agent[:email].split('@')[0]
      end
    end

    def after_load_object
      if (update? && (!User.current.can_edit_agent?(@item) || !(availability_update_allowed? || manage_user_ability?))) || (destroy? && (!User.current.can_edit_agent?(@item) || current_user_update?))
        Rails.logger.error "API V2 AgentsController Action: #{action_name}, UserId: #{@item.user_id}, CurrentUser: #{User.current.id}"
        render_request_error(:access_denied, 403)
      end
    end

    def load_object
      @item = api_current_user.id if me? || current_action?('revert_identity')
      @item ||= scoper.find_by_user_id(params[:id])
      log_and_render_404 unless @item
    end

    def build_object
      @item = scoper.new
    end

    def remove_ignore_params
      params[cname].except!(AgentConstants::IGNORE_PARAMS)
    end

    def validate_params(agent_params = nil)
      agent_params ||= params[cname]
      allowed_fields = "#{constants_class}::#{action_name.upcase}_FIELDS".constantize
      allowed_fields += AgentConstants::SKILLS_FIELDS if current_account.skill_based_round_robin_enabled?
      agent_params.permit(*allowed_fields)
      agent = AgentValidation.new(agent_params, @item, string_request_params?)
      render_custom_errors(agent, true) unless agent.valid?(action_name.to_sym)
    end

    def validate_params_for_export
      params[cname].permit(*AgentConstants::EXPORT_FIELDS)
      agent_export = AgentExportValidation.new(params[cname])
      render_custom_errors(agent_export, true) unless agent_export.valid?(action_name.to_sym)
    end

    def sanitize_params
      prepare_array_fields [:role_ids, :group_ids]
      params_hash = params[cname]
      user_attributes = AgentConstants::USER_FIELDS & params_hash.keys
      params_hash[:user_attributes] = params_hash.extract!(*user_attributes)
      params_hash[:user_attributes][:id] = @item.try(:user_id)
      ParamsHelper.assign_and_clean_params({ signature: :signature_html, ticket_scope: :ticket_permission }, params_hash)
    end

    def validate_filter_params
      allowed_fields = if index?
        AgentConstants::INDEX_FIELDS
      elsif current_action?('availability_count')
        AgentConstants::AVAILABILITY_COUNT_FIELDS
      end
      params.permit(*allowed_fields, *ApiConstants::DEFAULT_INDEX_FIELDS)
      @agent_filter = AgentFilterValidation.new(params)
      render_errors(@agent_filter.errors, @agent_filter.error_options) unless @agent_filter.valid?
    end

    def load_objects(scoper_options = nil)
      return super(@parsed_ocr_response.try(:[], 'ocr_agents') || [], false) if only_omni_channel_availability
      return super(scoper_options) if scoper_options

      super(
        if User.current.privilege?(:manage_users)
          # Preloading user as 'includes' introduces an additional outer join to users table while inner join with user already exists
          agents_filter(scoper).preload(:user)
        else
          agents_filter(scoper)
        end
      )
    end

    def assign_protected
      if params[cname][:user_attributes].key?(:role_ids)
        params[cname][:role_ids] = params[cname][:user_attributes][:role_ids]
        params[cname][:occasional] = false if Account.current.field_service_management_enabled? &&
                                              params[cname][:occasional].blank? &&
                                              params[cname][:agent_type] == Account.current.agent_types.find_by_name(Agent::FIELD_AGENT).agent_type_id
        # This is to forcefully call user callbacks only when role_ids are there.
        # As role_ids are not part of user_model(it is an association_reader), agent.update_attributes won't trigger user callbacks since user doesn't have any change.
        @item.user.safe_send(:attribute_will_change!, :role_ids_changed) if action_name.casecmp('UPDATE').zero?
      end
    end

    def assign_user_attributes
      params[:user][:helpdesk_agent] = true
      params[:user][:role_ids] = params[:user][:role_ids].presence || [Account.current.roles.find_by_name('Agent').id]
      params[:user][:agent_type] = params[:user][:agent_type].presence || AgentConstants::AGENT_TYPES[0]
      params[:user][:time_zone] = params[:time_zone].presence || Account.current.time_zone
      params[:user][:language] = params[:language].presence || Account.current.language
    end

    def assign_agent_attributes
      @item.assign_attributes(occasional: true, agent_type: Account.current.agent_types.find_by_name(Agent::SUPPORT_AGENT).agent_type_id,
                              signature_html: "<div dir=\"ltr\"><p><br></p>\r\n</div>")
      @item.user_id = @user.id
      @item.ticket_permission = params[:ticket_scope]
      @item.occasional = false if params[cname][:occasional] == false
      @item.agent_type = params[:agent_type] if params[:agent_type].to_s.present?
      @item.signature_html = params[cname][:signature_html] if params[cname][:signature_html].present?
      @item.freshcaller_enabled = params[:freshcaller_agent] || false
      @item.freshchat_enabled = params[cname][:freshchat_agent] if params[cname][:freshchat_agent].present?
      @item.scoreboard_level_id = params[:agent_level_id]
      assign_group_with_contribution_group
    end

    def assign_group_with_contribution_group
      group_ids = params[cname].delete(:group_ids)
      contribution_group_ids = params[cname].delete(:contribution_group_ids)
      @item.build_agent_groups_attributes(group_ids, contribution_group_ids)
    end

    def assign_avatar
      @user.avatar = @delegator.draft_attachments.first
    end

    def check_and_assign_field_agent_roles
      if params[cname][:agent_type] == Account.current.agent_types.find_by_name(Agent::FIELD_AGENT).agent_type_id
        params[:user][:role_ids] = [Account.current.roles.find_by_name('Field technician').id]
      end
    end

    def check_and_assign_skills_for_create
      return if params[:skill_ids].blank?

      formatted_skills = []
      rank = 1
      params[:skill_ids].each do |id|
        formatted_skills.push(skill_id: id, rank: rank, rank_handled_in_ui: true)
        rank += 1
      end
      params[:user][:user_skills_attributes] = formatted_skills
    end

    def check_and_assign_skills_for_update
      return unless params[cname].key?(:user_attributes) && params[cname][:user_attributes].key?(:skill_ids)

      current_skill_ids = params[cname][:user_attributes][:skill_ids]
      prev_skill_data = @item.user.user_skills.preload(:skill).map do |user_skill|
        { id: user_skill.id, skill_id: user_skill.skill_id }
      end
      prev_skill_ids = prev_skill_data.map { |skill_data| skill_data[:skill_id] }
      removed_skill_ids = prev_skill_ids - current_skill_ids
      formatted_skills = []
      rank = 1
      current_skill_ids.each do |skill_id|
        skill_hash = { skill_id: skill_id, rank: rank, rank_handled_in_ui: true }
        rank_index = prev_skill_ids.find_index(skill_id)
        skill_hash[:id] = prev_skill_data[rank_index][:id] if rank_index.present?
        formatted_skills.push(skill_hash)
        rank += 1
      end
      removed_skill_ids.each do |skill_id|
        formatted_skills.push(id: prev_skill_data[prev_skill_ids.find_index(skill_id)][:id], _destroy: true, rank_handled_in_ui: true)
      end
      params[cname][:user_attributes][:user_skills_attributes] = formatted_skills
      params[cname][:user_attributes].delete(:skill_ids)
    end

    def agents_filter(agents)
      @agent_filter.conditions.each do |key|
        clause = agents.api_filter(@agent_filter)[key.to_sym] || {}
        agents = if clause[:joins].present?
                   agents.joins(clause[:joins]).where(clause[:conditions])
                 else
                   agents.where(clause[:conditions])
                 end
      end
      load_from_cache? ? agents : agents.reorder(order_clause)
    end

    def load_from_cache?
      false
    end

    def scoper
      current_account.all_agents
    end

    def check_gdpr_pending?
      render_request_error :access_denied, 403 unless User.current.gdpr_pending?
    end

    def me?
      @me ||= current_action?('me')
    end

    def current_user_update?
      (@item.user_id == User.current.id)
    end

    def manage_user_ability?
      User.current.privilege?(:manage_users) || current_user_update?
    end

    def availability_update_allowed?
      params[cname].key?(:ticket_assignment) ? User.current.privilege?(:manage_availability) : current_user_update?
    end

    def allowed_to_access?
      me? ? true : super
    end

    def set_custom_errors(item = @item)
      ErrorHelper.rename_error_fields(AgentConstants::FIELD_MAPPINGS, item)
    end

    def error_options_mappings
      AgentConstants::FIELD_MAPPINGS
    end

    def fetch_portal_url
      main_portal? ? current_account.host : current_portal.portal_url
    end

    def load_data_export
      fetch_data_export_item(AgentConstants::EXPORT_TYPE)
    end

    def freshid_user_details(email)
      current_account.freshid_org_v2_enabled? ? Freshid::V2::Models::User.find_by_email(email.to_s) : Freshid::User.find_by_email(email.to_s)
    end

    def fetch_user_data_from_email
      return fetch_user_info_from_fresh_id if params[:old_email].blank? || params[:email].casecmp(params[:old_email]) != 0

      user = current_account.users.find_by_email(params[:old_email].to_s)
      user_info_hash(user)[:user] if user.present?
    end

    def fetch_user_info_from_fresh_id
      user = freshid_user_details(params[:email])
      user_hash = user_info_hash(User.new, user.as_json.symbolize_keys)[:user] if user.present?
      user_hash
    end

    def construct_search_in_freshworks_payload(user_hash, freshdesk_user_data)
      user_meta_info = { user_id: freshdesk_user_data.id, marked_for_hard_delete: freshdesk_user_data.marked_for_hard_delete?, deleted: freshdesk_user_data.deleted } if freshdesk_user_data
      { freshid_user_info: user_hash || {}, user_info: user_meta_info }
    end

    def order_clause
      field = order_filters_value(:order_by)
      order_type = order_filters_value(:order_type)
      "#{field} #{order_type}"
    end

    def order_filters_value(filter_key)
      filter_array = filter_key == :order_by ? AgentConstants::AGENTS_ORDER_BY : AgentConstants::AGENTS_ORDER_TYPE
      filter_value = @agent_filter.safe_send(filter_key).to_s.downcase if @agent_filter.conditions.include?(filter_key.to_s)
      filter_array.include?(filter_value) ? filter_value : filter_array[0]
    end

    def only_omni_channel_availability
      @only_omni_channel_availability ||= params[:only].eql?('availability')
    end

    def check_privilege
      success = super
      render_request_error(:access_denied, 403) if success && !private_api? && index? && !(only_omni_channel_availability || current_user.privilege?(:manage_users))
    end
end
