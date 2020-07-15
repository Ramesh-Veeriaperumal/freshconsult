module ContactsCompaniesConcern
  extend ActiveSupport::Concern
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Export::Util

  EXPORT_WORKERS = {
    'contact' => Export::ContactWorker,
    'company' => Export::CompanyWorker
  }.freeze

  def export_field_mappings(export_type)
    current_account.safe_send("#{export_type}_form").safe_send("#{export_type}_fields_from_cache").inject({}) do |a, e|
      fields_to_export.include?(e.name) ? a.merge!(e.label => e.name) : a
    end
  end

  def fields_to_export
    fields = params[cname][:fields]
    @export_fields ||= [*fields[:default_fields],
                        *(fields[:custom_fields] ||
                          []).collect { |field| "cf_#{field}" }]
  end

  def portal_url
    main_portal? ? current_account.host : current_portal.portal_url
  end

  def contact_company_export(export_type)
    @validation_klass = export_type == 'contact' ? 'ContactExportValidation' : 'ExportCsvValidation'
    params_hash = params[cname].merge('export_type' => export_type)
    return false unless validate_body_params(nil, params_hash)
    fields = "#{export_type.capitalize}Constants::EXPORT_ARRAY_FIELDS".constantize
    params[cname][:fields].permit(*fields)
    sanitize_body_params
    create_export export_type
    file_hash @data_export.id
    args = { csv_hash: export_field_mappings(export_type),
             user: api_current_user.id,
             portal_url: portal_url,
             data_export: @data_export.id }
    EXPORT_WORKERS[export_type].perform_async(args)
  end

  def assign_avatar
    given_avatar_id = params[cname][:avatar_id]
    if given_avatar_id.present?
      @item.avatar = @delegator.draft_attachments.first
      avatar_changes_for_auditlog(:added, @item.avatar) if @item.is_a? Company
    end
  end

  def mark_avatar_for_destroy
    avatar_id = @item.avatar.id if params[cname].key?('avatar_id') && @item.avatar
    if avatar_id.present? && avatar_id != params[cname][:avatar_id]
      avatar_changes_for_auditlog(:removed, @item.avatar) if @item.is_a? Company
      @item.avatar_attributes = { id: avatar_id, _destroy: 1 }
    end
  end

  def avatar_changes_for_auditlog(key, value)
    @item.avatar_changes = {} if @item.avatar_changes.nil?
    @item.avatar_changes.merge!(value.present? ? { "#{key}": { id: value.id, name: value.content_file_name } } : {})
  end

  def fetch_data_export_item(export_type)
    @data_export = current_account.data_exports.find_by_source_and_token(DataExport::EXPORT_TYPE[export_type.to_sym], params[:id])
    return log_and_render_404 unless @data_export
  end

  def check_export_limit(export_type)
    if DataExport.safe_send("#{export_type}_export_limit_reached?")
      export_limit = DataExport.safe_send("#{export_type}_export_limit")
      render_request_error_with_info(:export_limit_reached, 429,
                                     { max_limit: export_limit, export_type: export_type },
                                     max_simultaneous_export: export_limit)
    end
  end

  def fetch_export_details
    @export_details = {
      id: @data_export.token,
      status: fetch_status
    }
    if @data_export.status == DataExport::EXPORT_STATUS[:completed]
      attachment = @data_export.attachment
      options = { expires: 5.minutes, secure: true, response_content_type: attachment.content_content_type, response_content_disposition: 'attachment' }
      url = AwsWrapper::S3Object.url_for(attachment.content.path(:original), attachment.content.bucket_name, options)
      @export_details.merge!(download_url: url)
    end
    @export_details
  end

  def fetch_status
    export_status = DataExport::EXPORT_STATUS.key(@data_export.status)
    if DataExport::EXPORT_IN_PROGRESS_STATUS.include?(export_status)
      'in_progress'
    else
      export_status
    end
  end
end
