class Email::MailboxesController < ApiApplicationController
  include Email::Mailbox::Constants
  include Email::Mailbox::Utils
  include HelperConcern
  decorate_views

  before_filter :check_multiple_emails_feature, only: [:create]

  def create
    delegator_params = {
      imap_mailbox_attributes: cname_params[:imap_mailbox_attributes],
      smtp_mailbox_attributes: cname_params[:smtp_mailbox_attributes]
    }
    return unless validate_delegator(@item, delegator_params)

    if @item.save
      render :create, status: 201
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

  private

    def scoper
      current_account.all_email_configs
    end
    
    def check_multiple_emails_feature
      render_request_error(:require_feature, 403, feature: 'multiple_emails') unless current_account.multiple_emails_enabled?
    end

    def before_validate_params
      cname_params[:mailbox_type].try(:downcase!)
      cname_params[:custom_mailbox][:access_type].try(:downcase!) if cname_params[:custom_mailbox].present? && cname_params[:access_type].present?
      cname_params[:custom_mailbox][:incoming][:authentication].try(:downcase!) if cname_params[:custom_mailbox].present? && cname_params[:custom_mailbox][:incoming].present?
    end

    def validate_params
      before_validate_params
      validate_body_params
    end

    def sanitize_params
      ParamsHelper.assign_and_clean_params(EmailMailboxConstants::PARAMS_MAPPING, cname_params)
      sanitize_custom_mailbox_params
      ParamsHelper.clean_params(EmailMailboxConstants::PARAMS_TO_DELETE, cname_params)
      assign_to_email
    end

    def sanitize_custom_mailbox_params
      if cname_params[:mailbox_type] == CUSTOM_MAILBOX && cname_params[:custom_mailbox].present?
        sanitize_incoming_params
        sanitize_outgoing_params
      end
    end

    def sanitize_incoming_params
      if cname_params[:custom_mailbox][:incoming].present?
        ParamsHelper.assign_and_clean_params(EmailMailboxConstants::ACCESS_TYPE_PARAMS_MAPPING, cname_params[:custom_mailbox][:incoming])
        cname_params[:imap_mailbox_attributes] = cname_params[:custom_mailbox].delete(:incoming)
        cname_params[:imap_mailbox_attributes][:authentication] = IMAP_CRAM_MD5 if cname_params[:imap_mailbox_attributes][:authentication] == CRAM_MD5
      end
    end

    def sanitize_outgoing_params
      if cname_params[:custom_mailbox][:outgoing].present?
        ParamsHelper.assign_and_clean_params(EmailMailboxConstants::ACCESS_TYPE_PARAMS_MAPPING, cname_params[:custom_mailbox][:outgoing])
        cname_params[:smtp_mailbox_attributes] = cname_params[:custom_mailbox].delete(:outgoing)
      end
    end

    def assign_to_email
      cname_params[:to_email] = construct_to_email(cname_params[:reply_email], current_account.full_domain)
    end

    def set_custom_errors(item = @item)
      ErrorHelper.rename_error_fields(EmailMailboxConstants::FIELD_MAPPINGS, item)
      {}
    end

    def constants_class
      EmailMailboxConstants.to_s.freeze
    end
end
