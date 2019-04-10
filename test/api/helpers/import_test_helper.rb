module ImportTestHelper
  def remove_imports_if_exists(type)
    if @account.send("#{type}_imports")
      @account.send("#{type}_imports").destroy_all
      @account.reload
    end
  end

  def set_keys(account, import, type)
    format_params = {
      account_id: account.id,
      import_id: import.id
    }
    records = [{ key: format("Redis::Keys::Others::#{type}_IMPORT_FAILED_RECORDS".constantize, format_params),
                 value: 1 },
               { key: format("Redis::Keys::Others::#{type}_IMPORT_FINISHED_RECORDS".constantize, format_params),
                 value: 1 },
               { key: format("Redis::Keys::Others::#{type}_IMPORT_TOTAL_RECORDS".constantize, format_params),
                 value: 2 }]
    records.each { |record| set_others_redis_key(record[:key], record[:value]) }
    Helpdesk::Attachment.any_instance.stubs(:attachment_url_for_api)
                        .returns('spec/fixtures/files/attachment.csv')
  end

  def import_params(type, field_params)
    { file: fixture_file_upload("files/#{type.pluralize}_import.csv", 'text/csv', :binary),
      fields: field_params }
  end

  def import_show_result(import)
    {
      id: import.id,
      created_at: import.created_at.try(:utc).iso8601
    }
  end
end
