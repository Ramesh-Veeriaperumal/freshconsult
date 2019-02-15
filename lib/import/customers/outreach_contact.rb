class Import::Customers::OutreachContact < Import::Customers::Contact
  def initialize(params = {})
    super params
    @contact_ids = []
    @is_outreach_import = true
  end

  def import
    super
    @contact_ids.presence || []
  end

  def save_contact_id
    @contact_ids << @item.id if @item.present? && @item.id.present?
  end

  def parse_csv_file
    csv_file = AwsWrapper::S3Object.find(@customer_params[:file_location], S3_CONFIG[:bucket])
    row_count = 0
    CSVBridge.parse(content_of(csv_file)).each_slice(IMPORT_BATCH_SIZE).with_index do |rows, index|
      @failed_count = 0
      rows.each_with_index do |row, inner_index|
        row = row.collect{ |r| Helpdesk::HTMLSanitizer.clean(r.to_s) }
        (@csv_headers = row) && next if index.zero? && inner_index.zero?

        break if row_count >= Proactive::Constants::SIMPLE_OUTREACH_IMPORT_LIMIT

        row_count += 1
        assign_field_values row
        next if is_user? && !@item.nil? && @item.helpdesk_agent?

        save_item row
      end
      break if row_count >= Proactive::Constants::SIMPLE_OUTREACH_IMPORT_LIMIT
    end
  rescue => e
    Rails.logger.error "Error while reading csv data ::#{e.message}\n#{e.backtrace.join("\n")}"
    NewRelic::Agent.notice_error(e, { :description =>
      'The file format is not supported. Please check the CSV file format!' })
    raise e
  end

  def customer_import
    @import ||= current_account.outreach_contact_imports.find_by_id(@params[:data_import])
  end

  def notify_and_cleanup(corrupted = false)
    notify_mailer corrupted
  end

  def notify_mailer(param = false)
    UserNotifier.notify_proactive_outreach_import(mailer_params(param))
  end

  def mailer_params(corrupted)
    hash = {
      user: @current_user,
      type: @params[:type].pluralize,
      outreach_name: 'Sample',
      success_count: @created + @updated,
      failed_count: @failed_items.count
    }

    if corrupted
      hash[:corrupted] = true
    elsif @wrong_csv
      hash[:wrong_csv] = @wrong_csv
    else
      # Attachment(csv file) will not be send, if the file is more than 1MB
      hash.merge!(file_path: failed_file_path, file_name: failed_file_name) unless @failed_items.blank? || failed_file_size > ONE_MEGABYTE
      hash[:import_success] = true if @failed_items.blank?
    end
    hash
  end
  # def cleanup_file
  # end
end
