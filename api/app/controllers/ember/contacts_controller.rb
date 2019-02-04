module Ember
  class ContactsController < ApiContactsController
    include DeleteSpamConcern
    include HelperConcern
    include CustomerActivityConcern
    include AgentContactConcern
    include ContactsCompaniesConcern
    include SegmentConcern

    decorate_views(decorate_object: [:quick_create])

    SLAVE_ACTIONS = %w(index activities).freeze
    before_filter :can_change_password?, :validate_password_change, only: [:update_password]
    before_filter :validate_and_process_query_hash, only: [:index], if: :segments_enabled?

    def create
      assign_protected
      delegator_params = construct_delegator_params
      return unless validate_delegator(@item, delegator_params)
      build_user_emails_attributes if @email_objects.any?
      build_other_companies if @all_companies
      assign_avatar
      if @item.create_contact!(params[cname][:active])
        render :show, status: 201
      else
        render_custom_errors
      end
    end

    def show
      preload_associations
    end

    def update
      assign_protected
      delegator_params = construct_delegator_params
      @item.assign_attributes(validatable_delegator_attributes)
      @item.save_tags
      return unless validate_delegator(@item, delegator_params)
      build_user_emails_attributes if @email_objects.any?
      build_other_companies if @all_companies
      mark_avatar_for_destroy
      User.transaction do
        @item.update_attributes!(params[cname].except(:avatar_id))
        assign_avatar
      end
      @item.reload
    rescue
      render_custom_errors
    end

    def index
      if filter_api?
        handle_segments
      else
        super
        response.api_meta = @items_count ? { count: @items_count } : {}
        response.api_meta[:next_page] = @more_items
      end
    end

    def quick_create
      params_hash = params[cname]
      params_hash[:action] = params[:action].to_sym

      return unless validate_body_params(nil, params_hash)
      build_object
      return unless validate_delegator(@item, {primary_email: params[:email]}) if params[:email]

      if @item.create_contact!(params[cname][:active])
        render :show, location: api_contact_url(@item.id), status: 201
      else
        render_custom_errors
      end
    end


    def bulk_send_invite
      bulk_action do
        @items_failed = []
        @items.each do |item|
          @items_failed << item unless send_activation_mail(item)
        end
      end
    end

    def update_password
      @item.password = params[cname][:password]
      @item.active = true
      if @item.save
        @item.reset_perishable_token!
        head 204
      else
        ErrorHelper.rename_error_fields({ base: :password }, @item)
        render_errors(@item.errors)
      end
    end

    def whitelist
      return head 204 if whitelist_item(@item)
      render_errors(@item.errors) if @item.errors.any?
    end

    def bulk_whitelist
      bulk_action do
        @items_failed = []
        @items.each do |item|
          @items_failed << item unless whitelist_item(item)
        end
      end
    end


    def timeline
      items = HyperTrail::Timeline.new(params.merge!(type: cname).to_h).fetch
      activities = construct_timeline_activities(items)
      activities = decorate_activities(activities)
      @activities = activities.each_with_object({}) do |act, ret|
        (ret[act.delete(:activity_type).to_sym.downcase] ||= []).push(act)
        ret
      end
      if activities.count >= CompanyConstants::MAX_ACTIVITIES_COUNT
        response.api_meta = { more_tickets: true }
      end
    rescue
      render_request_error(:internal_error, 503)
    end

    def self.wrap_params
      Ember::ContactConstants::EMBER_WRAP_PARAMS
    end

    private

      def scoper
        unless params[:tag].blank?
          tag = current_account.tags.find_by_name(params[:tag])
          return (tag || Helpdesk::Tag.new).contacts
        end
        super
      end

      def load_objects
      # preload(:flexifield) will avoid n + 1 query to contact field data.
        items = contacts_filter(scoper).preload(preload_options).order('users.name')
        @items_count = items.count if calculate_count_query?
        @items = paginate_items(items)
      end

      def load_object(items = scoper)
        @item = items.find_by_id(params[:id])
        @item ||= deleted_agent

        log_and_render_404 unless @item
      end

      def deleted_agent
        @deleted_agent ||= current_account.all_users.where(deleted: true, helpdesk_agent:true).find_by_id(params[:id])
      end

      def construct_delegator_params
        {
          other_emails: @email_objects[:old_email_objects],
          primary_email: @email_objects[:primary_email],
          custom_fields: params[cname][:custom_field],
          default_company: @def_company.try(:id),
          avatar_id: params[cname][:avatar_id]
        }
      end

      def preload_options
        if Ember::ContactConstants::PRELOAD_OPTIONS.key?(action_name.to_sym)
          Ember::ContactConstants::PRELOAD_OPTIONS[action_name.to_sym]
        else
          (super - [:default_user_company]) | preload_with_sideload
        end
      end

      def preload_with_sideload
        if sideload_options.present? && sideload_options.include?('company')
          [:user_emails, :tags, :avatar, { user_companies: [:company] }]
        else
          [:user_emails, :tags, :avatar, :user_companies]
        end
      end

      def fetch_objects(items = scoper)
        @items = items.preload(preload_options).find_all_by_id(params[cname][:ids])
      end

      def preload_associations
        return unless sideload_options.present? && sideload_options.include?('company')
        ActiveRecord::Associations::Preloader.new(@item, preload_options).run
      end

      def sideload_options
        index? ? @contact_filter.try(:include_array) : @include_validation.try(:include_array)
      end

      def sanitize_params
        construct_or_delete_primary_company
        super
      end

      def launch_party_name
        FeatureConstants::TIMELINE if action_name == 'timeline'
      end

      def construct_or_delete_primary_company
        if params[cname][:company].present?
          @company_param = params[cname].delete(:company)
          @def_company = find_or_create_company(@company_param)
          return unless @def_company
          build_primary_company
        elsif delete_primary_company?
          company_attributes = []
          @item.user_companies.each do |user_company|
            company_attributes << {
              'id' => user_company.id,
              '_destroy' => 1
            }
          end
          @item.user_companies_attributes = Hash[(0...company_attributes.size).zip company_attributes]
        end
      end

      def build_primary_company
        if params[cname].key?(:other_companies)
          @company_param[:default] = true
        else
          params[cname][:company_id] = @def_company.id
          params[cname][:client_manager] = @company_param[:view_all_tickets] || false
        end
      end

      def delete_primary_company?
        !current_account.multiple_user_companies_enabled? && update? &&
          params[cname].key?(:company) && params[cname][:company].blank?
      end

      def construct_all_companies
        @all_companies = params[cname].delete(:other_companies) + [@company_param]
        @all_companies.compact!.try(:uniq!)
      end

      def build_other_companies
        company_attributes = []
        if update?
          @all_company_ids = @all_companies.map { |c| c[:id].to_i }.compact.uniq
          current_companies.each do |user_company|
            company_attributes << {
              'id' => user_company.id,
              '_destroy' => 1
            } if @all_company_ids.exclude? user_company.company_id
          end
        end
        @all_companies.each do |comp|
          company = find_or_create_company(comp) if comp[:id].blank?
          company_attributes << user_company_hash(company || comp, comp[:view_all_tickets] || false, comp[:default])
        end
        @item.user_companies_attributes = Hash[(0...company_attributes.size).zip company_attributes]
      end

      def find_or_create_company(company)
        company[:id].present? ? current_account.companies.find_by_id(company[:id]) :
          current_account.companies.find_or_create_by_name(company[:name])
      end

      def user_company_hash(company, cm, default = false)
        uc_id = current_companies.find { |uc| uc.company_id.to_s == company[:id].to_s }.try(:id) if update?
        {
          id: uc_id,
          company_id: company[:id],
          client_manager: cm,
          default: default || false
        }
      end

      def render_201_with_location(template_name: "api_contacts/#{action_name}", location_url: 'api_contact_url', item_id: @item.id)
        render template_name, location: safe_send(location_url, item_id), status: 201
      end

      def send_activation_mail(item)
        @contact_delegator = ContactDelegator.new(item)
        valid = @contact_delegator.valid?(:send_invite)
        item.deliver_activation_instructions!(current_portal, true) if valid && item.has_email?
        valid
      end

      def can_change_password?
        render_errors(password: :"Not allowed to change.") unless @item.allow_password_update?
      end

      def validate_params
        @contact_fields = current_account.contact_form.custom_contact_fields
        @name_mapping = CustomFieldDecorator.name_mapping(@contact_fields)
        custom_fields = @name_mapping.empty? ? [nil] : @name_mapping.values

        field = Ember::ContactConstants::CONTACT_FIELDS | ['custom_fields' => custom_fields]
        params[cname].permit(*field)
        ParamsHelper.modify_custom_fields(params[cname][:custom_fields], @name_mapping.invert)
        contact = Ember::ContactValidation.new(params[cname], @item, string_request_params?)
        render_custom_errors(contact, true) unless contact.valid?(action_name.to_sym)
      end

      def current_segment
        @current_segment ||= contact_filters.find_by_id(params[:filter])
      end

      def contact_filters
        current_account.contact_filters
      end

      def validate_url_params
        params.permit(*ContactConstants::SHOW_FIELDS, *ApiConstants::DEFAULT_PARAMS)
        @include_validation = ContactFilterValidation.new(params, nil, string_request_params?)
        render_errors(@include_validation.errors, @include_validation.error_options) unless @include_validation.valid?
      end

      def validate_password_change
        params[cname].permit(:password)
        contacts_validation = Ember::ContactValidation.new(params, @item)
        return true if contacts_validation.valid?(action_name.to_sym)
        render_errors contacts_validation.errors, contacts_validation.error_options
        false
      end

      def whitelist_item(item)
        unless item.blocked
          item.errors.add(:blocked, 'is false. You can whitelist only blocked users.')
          return false
        end
        item.blocked = false
        item.whitelisted = true
        item.deleted = false
        item.blocked_at = nil
        item.save
      end

      def restore_item(item)
        return false unless item.deleted
        return false if item.agent_deleted_forever?
        item.deleted = false
        item.save
      end

      def constants_class
        :ContactConstants.to_s.freeze
      end

      def calculate_count_query?
        private_api? && !current_account.stop_contacts_count_query_enabled?
      end
      wrap_parameters(*wrap_params)
  end
end
