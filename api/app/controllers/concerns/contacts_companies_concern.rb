module ContactsCompaniesConcern
  extend ActiveSupport::Concern
  include Redis::RedisKeys
  include Redis::OthersRedis

  EXPORT_WORKERS = {
    "contact" => Export::ContactWorker,
    "company" => Export::CompanyWorker
  }

  def export_field_mappings
    current_account.safe_send("#{cname}_form").safe_send("#{cname}_fields_from_cache").inject({}) do |a, e|
      fields_to_export.include?(e.name) ? a.merge!(e.label => e.name) : a
    end
  end

  def fields_to_export
    @export_fields ||= [*params[cname][:default_fields],
                        *(params[cname][:custom_fields] ||
                          []).collect { |field| "cf_#{field}" }]
  end

  def portal_url
    main_portal? ? current_account.host : current_portal.portal_url
  end

  def contact_company_export_csv export_type
    @validation_klass = 'ExportCsvValidation'
    params_hash = params[cname].merge("export_type"=>cname)
    return false unless validate_body_params(nil, params_hash)
    sanitize_body_params
    args = { :csv_hash => export_field_mappings,
             :user => api_current_user.id,
             :portal_url => portal_url }
    EXPORT_WORKERS[export_type].perform_async(args)
  end

  def assign_avatar
    given_avatar_id = params[cname][:avatar_id]
    @item.avatar = @delegator.draft_attachments.first if given_avatar_id.present?
  end

  def mark_avatar_for_destroy
    avatar_id = @item.avatar.id if params[cname].key?('avatar_id') && @item.avatar
    @item.avatar_attributes = { id: avatar_id, _destroy: 1 } if avatar_id.present? &&
                                                                avatar_id != params[cname][:avatar_id]
  end
end
