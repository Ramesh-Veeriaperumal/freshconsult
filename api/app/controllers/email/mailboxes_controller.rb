class Email::MailboxesController < ApiApplicationController
  include Email::Mailbox::Constants
  include Email::Mailbox::Utils
  include Admin::EmailConfig::Utils
  include HelperConcern
  include MailboxConcern
  decorate_views

  before_filter :check_multiple_emails_feature, only: [:create]
  skip_before_filter :before_load_object, :after_load_object, only: [:send_verification]

  def index
    super
    response.api_meta = { count: @items_count }
  end

  def create
    return unless validate_delegator(@item)

    if @item.save
      remove_cached_oauth_value if oauth_reference
      render :create, status: 201
    else
      render_custom_errors
    end
  end

  def update
    @item.assign_attributes(validatable_delegator_attributes)
    return unless validate_delegator(@item)

    if @item.update_attributes(cname_params)
      remove_cached_oauth_value if oauth_reference
      @item.reload
      render :update, status: 200
    else
      render_custom_errors
    end
  end

  def destroy
    if @item.primary_role
      render_errors(error: :cannot_delete_default_reply_email)
    else
      @item.destroy
      head 204
    end
  end

  def send_verification
    if @item.active
      render_request_error(:active_mailbox_verification, 409)
    else
      remove_bounced_email(@item.reply_email) # remove the email from bounced email list so that 'resend verification' will send mail again.

      @item.set_activator_token
      @item.save
      head 204
    end
  end

  private

    def scoper
      if index? && params[:order_by] == EmailMailboxConstants::FAILURE_CODE
        current_account.all_email_configs.reorder('imap_mailboxes.error_type > 0 or smtp_mailboxes.error_type > 0 DESC, primary_role DESC')
      else
        current_account.all_email_configs.reorder('primary_role DESC')
      end
    end

    def check_multiple_emails_feature
      render_request_error(:require_feature, 403, feature: 'multiple_emails') unless current_account.multiple_emails_enabled?
    end

    def after_load_object
      @item.imap_mailbox.try(:mark_for_destruction) if update? && imap_be_destroyed?
      @item.smtp_mailbox.try(:mark_for_destruction) if update? && smtp_be_destroyed?
    end

    def before_validate_params
      cname_params[:mailbox_type].try(:downcase!)
      cname_params[:custom_mailbox][:access_type].try(:downcase!) if cname_params[:custom_mailbox].present? && cname_params[:access_type].present?
      cname_params[:custom_mailbox][:incoming][:authentication].try(:downcase!) if cname_params[:custom_mailbox].present? && cname_params[:custom_mailbox][:incoming].present?
      cname_params[:custom_mailbox][:outgoing][:authentication].try(:downcase!) if cname_params[:custom_mailbox].present? && cname_params[:custom_mailbox][:outgoing].present?
    end

    def validate_params
      before_validate_params
      validate_body_params(@item)
    end

    def validatable_delegator_attributes
      cname_params.select do |attr, value|
        if EmailMailboxConstants::VALIDATABLE_DELEGATOR_ATTRIBUTES.include?(attr)
          cname_params.delete(attr)
          true
        end
      end
    end

    def sanitize_params
      ParamsHelper.assign_and_clean_params(EmailMailboxConstants::PARAMS_MAPPING, cname_params)
      sanitize_custom_mailbox_params
      ParamsHelper.clean_params(EmailMailboxConstants::PARAMS_TO_DELETE, cname_params)
      assign_to_email
    end

    def sanitize_custom_mailbox_params
      if cname_params[:custom_mailbox].present?
        sanitize_incoming_params
        sanitize_outgoing_params
      end
    end

    def sanitize_incoming_params
      if cname_params[:custom_mailbox][:incoming].present?
        ParamsHelper.assign_and_clean_params(EmailMailboxConstants::ACCESS_TYPE_PARAMS_MAPPING, cname_params[:custom_mailbox][:incoming])
        cname_params[:imap_mailbox_attributes] = cname_params[:custom_mailbox].delete(:incoming)
        cname_params[:imap_mailbox_attributes][:authentication] = IMAP_CRAM_MD5 if cname_params[:imap_mailbox_attributes][:authentication] == CRAM_MD5
        cname_params[:imap_mailbox_attributes][:id] = @item.imap_mailbox.id if update? && @item.imap_mailbox.present?
        sanitize_incoming_params_for_oauth if incoming_oauth?
      end
    end

    def sanitize_incoming_params_for_oauth
      update_cached_values(IMAP) && return if valid_reference?
      cname_params[:imap_mailbox_attributes][:password] = @item.imap_mailbox.decrypt_password(@item.imap_mailbox.password) if update? && @item.imap_mailbox.present?
      update_incoming_and_outgoing(IMAP) && return if update? && incoming_to_be_updated?
      render_errors(error: :invalid_oauth_reference) if update? && invalid_incoming_update?
    end

    def sanitize_outgoing_params
      if cname_params[:custom_mailbox][:outgoing].present?
        ParamsHelper.assign_and_clean_params(EmailMailboxConstants::ACCESS_TYPE_PARAMS_MAPPING, cname_params[:custom_mailbox][:outgoing])
        cname_params[:smtp_mailbox_attributes] = cname_params[:custom_mailbox].delete(:outgoing)
        cname_params[:smtp_mailbox_attributes][:id] = @item.smtp_mailbox.id if update? && @item.smtp_mailbox.present?
        sanitize_outgoing_params_for_oauth if outgoing_oauth?
      end
    end

    def update_incoming_and_outgoing(type)
      mailbox_type = type == SMTP ? IMAP_MAILBOX : SMTP_MAILBOX
      mailbox = @item.safe_send(mailbox_type)
      attribute = "#{type}_mailbox_attributes".to_sym
      cname_params[attribute][:password] = mailbox.decrypt_password(mailbox.password)
      cname_params[attribute][:refresh_token] = mailbox.decrypt_refresh_token(mailbox.refresh_token)
    end

    def update_cached_values(type)
      oauth_token, refresh_token = fetch_cached_auth_values
      attribute = "#{type}_mailbox_attributes".to_sym
      cname_params[attribute][:password] = oauth_token
      cname_params[attribute][:refresh_token] = refresh_token
    end

    def sanitize_outgoing_params_for_oauth
      update_cached_values(SMTP) && return if valid_reference?
      cname_params[:smtp_mailbox_attributes][:password] = @item.smtp_mailbox.decrypt_password(@item.smtp_mailbox.password) if update? && @item.smtp_mailbox.present?
      update_incoming_and_outgoing(SMTP) && return if update? && outgoing_to_be_updated?
      render_errors(error: :invalid_oauth_reference) if update? && invalid_outgoing_update?
    end

    def assign_to_email
      return unless cname_params[:reply_email].present?

      cname_params[:to_email] = construct_to_email(cname_params[:reply_email], current_account.full_domain)
    end

    def validate_filter_params
      @validation_klass = Email::MailboxFilterValidation.to_s.freeze
      validate_query_params
    end

    def paginate_options(is_array = false)
      options = super(is_array)
      options[:order] = order_clause if params[:order_by].present? && params[:order_by] != EmailMailboxConstants::FAILURE_CODE
      options
    end

    def paginate_scoper(items, options)
      items.order(options[:order]).paginate(options.except(:order)) # rubocop:disable Gem/WillPaginate
    end

    def order_clause
      "#{params[:order_by].to_sym} #{order_type} "
    end

    def order_type
      params[:order_type] || EmailMailboxConstants::DEFAULT_ORDER_TYPE
    end

    def set_custom_errors(item = @item)
      ErrorHelper.rename_error_fields(EmailMailboxConstants::FIELD_MAPPINGS, item)
      {}
    end

    def constants_class
      EmailMailboxConstants.to_s.freeze
    end

    def load_objects
      super mailboxes_filter(scoper.includes(:imap_mailbox, :smtp_mailbox))
    end

    def mailboxes_filter(mailboxes)
      filter_params = sanitize_filter_params(mailboxes_filter_conditions)
      filter_params.each do |key, value|
        clause = mailboxes.mailbox_filter(filter_params, private_api?)[key.to_sym] || {}
        mailboxes = mailboxes.where(clause[:conditions])
      end
      mailboxes
    end

    def mailboxes_filter_conditions
      params.select do |key, value|
        EmailMailboxConstants::INDEX_FIELDS.include?(key)
      end
    end

    def sanitize_filter_params(filter_params)
      sanitize_support_email_filter(filter_params) if filter_params.include?('support_email')
      sanitize_forward_email_filter(filter_params) if filter_params.include?('forward_email')
      sanitize_active_filter(filter_params) if filter_params.include?('active')
      filter_params
    end

    def sanitize_support_email_filter(filter_params)
      filter_params['reply_email'] = filter_params.delete('support_email').tr('*', '%')
    end

    def sanitize_forward_email_filter(filter_params)
      filter_params['to_email'] = filter_params.delete('forward_email')
    end

    def sanitize_active_filter(filter_params)
      filter_params['active'] = filter_params['active'].to_bool
    end
end
