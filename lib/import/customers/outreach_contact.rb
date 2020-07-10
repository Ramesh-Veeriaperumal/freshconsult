class Import::Customers::OutreachContact < Import::Customers::Contact
  include Proactive::Constants
  include Proactive::ProactiveUtil

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
    csv_file = AwsWrapper::S3.read_io(S3_CONFIG[:bucket], @customer_params[:file_location])
    row_count = 0
    max_limit_exceeded = false
    CSVBridge.parse(content_of(csv_file)).each_slice(IMPORT_BATCH_SIZE).with_index do |rows, index|
      @failed_count = 0
      rows.each_with_index do |row, inner_index|
        row = row.collect{ |r| Helpdesk::HTMLSanitizer.clean(r.to_s) }
        (@csv_headers = row) && next if index.zero? && inner_index.zero?

        break if row_count >= max_limit

        row_count += 1
        assign_field_values row
        next if is_user? && !@item.nil? && @item.helpdesk_agent?

        save_item row
        if row_count >= max_limit
          max_limit_exceeded = true
          break
        end
      end
      break if max_limit_exceeded
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
    UserNotifier.send_email(:notify_proactive_outreach_import, @current_user.email, mailer_params(param))
  end

  def max_limit
    @max_limit ||= outreach_import_limit
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
      hash.merge!(file_path: failed_file_path, file_name: failed_file_name) unless @failed_items.blank? || failed_file_size > FIVE_MEGABYTE
      hash.merge!(attachments: [@import.attachments.find_by_content_file_name(failed_file_name)]) unless @failed_items.blank?
      hash[:import_success] = true if @failed_items.blank?
    end
    hash
  end

  # def cleanup_file
  #   @import.attachments.destroy_all
  # end
end
