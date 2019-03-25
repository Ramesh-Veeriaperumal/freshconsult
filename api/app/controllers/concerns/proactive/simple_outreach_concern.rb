module Proactive::SimpleOutreachConcern
  extend ActiveSupport::Concern
  include SimpleOutreachConstants

  protected

  def email_validation_request_params
    email_params
  end

  def email_validation_fields
    COMPOSE_EMAIL_FIELDS
  end

  def email_validation_action
    "simple_outreach_#{action_name}".to_sym
  end

  def email_params
    @email_params ||= params[cname][:action][:email].except(:schedule_details).dup if email_params_present?
  end

  def simple_outreach_delegator_item
    Object.new
  end

  def simple_outreach_delegator_options
    options_hash = {}
    options_hash = { email_config_id: email_params[:email_config_id] } if email_params_present? && email_params.key?(:email_config_id)
    options_hash.merge!(
        attachment_id: cname_params[:selection][:contact_import][:attachment_id],
        attachment_file_name: cname_params[:selection][:contact_import][:attachment_file_name]
      ) if csv_import? && action_name.to_sym == :create
    options_hash
  end

  def simple_outreach_validation_params_hash
    type = cname_params[:selection][:type] if type_present?
    outreach_hash = {
      type: type,
      selection: cname_params[:selection]
    }
  end

  def simple_outreach_validation_request_params
    @outreach_params ||= cname_params.except(:action).dup
  end

  def simple_outreach_validation_fields
    create? ? (SIMPLE_OUTREACH_FIELDS | ['selection' => SELECTION_FIELDS] | ['contact_import' => CONTACT_IMPORT_FIELDS]) : (SIMPLE_OUTREACH_FIELDS - ['selection'])
  end

  def customer_import_validation_params_hash
    {
      import_type: IMPORT_TYPE,
      contact_import: cname_params[:selection][:contact_import]
    }
  end

  def customer_import_validation_permit_params?
    false
  end

  def customer_import_validation_action
    "simple_outreach_#{action_name}".to_sym
  end

  def csv_import?
    type_present? && cname_params[:selection][:type] == SELECTION_IMPORT
  end

  def type_present?
    cname_params[:selection].present? && cname_params[:selection][:type].present?
  end

  def email_params_present?
    params[cname][:action].present? && params[cname][:action][:email].present?
  end
end
