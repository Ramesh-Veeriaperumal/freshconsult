require 'csv'
class Export::Customer
  include ExportCsvUtil
  include Rails.application.routes.url_helpers
  include Export::Util

  VALUE_MAPPING = {
    "Language" => "language_name",
    "Company" => "company_names_for_export",
    "Can see all tickets from this company" => "client_managers_for_export"
  }

  def initialize(csv_hash, portal_url, type, data_export)
    @csv_hash = csv_hash
    @portal_url = portal_url
    @type = type
    @data_export = Account.current.data_exports.find_by_id(data_export)
  end

  def export_data
    csv_string = ""
    @headers = delete_invisible_fields
    @file_path = generate_file_path(@type, 'csv')
    write_export_file(@file_path) do |file|
      unless @csv_hash.blank?
        write_csv(file, @headers)
        map_csv(file)
      end
    end
    upload_file(@file_path)
    DataExportMailer.deliver_customer_export(email_params.merge(url: hash_url_with_token(@portal_url, @data_export.token)))
  rescue => e
    NewRelic::Agent.notice_error(e)
    puts "Error  ::#{e.message}\n#{e.backtrace.join("\n")}"
    @data_export.failure!(e.message + "\n" + e.backtrace.join("\n"))
    DataExportMailer.export_failure(email_params)
  ensure
    # Moving data exports entry to failed status in case of any failures
    export_status = DataExport::EXPORT_STATUS.key(@data_export.status)
    if !@data_export.destroyed? && DataExport::EXPORT_IN_PROGRESS_STATUS.include?(export_status)
      Rails.logger.error "#{@type} export status at the end of export job :: #{@data_export.status}"
      @data_export.failure!('Export::Failed')
      DataExportMailer.export_failure(email_params)
    end
    schedule_export_cleanup(@data_export, @type) if @data_export.present?
  end

  private

    def map_csv(file)
      Sharding.run_on_slave do
        Account.current.safe_send(@type.pluralize).preload(:flexifield).find_in_batches(:batch_size => 300) do |items|
          items.each do |record|
            csv_data = []
            @headers.each do |val|
              csv_data << strip_equal(record.safe_send(VALUE_MAPPING.fetch(val, @csv_hash[val]))) if record.respond_to?(VALUE_MAPPING.fetch(val, @csv_hash[val]))
            end
            write_csv(file, csv_data) if csv_data.any?
          end
        end
      end
    end

    def delete_invisible_fields
      headers = @csv_hash.keys
      headers.delete_if{|header_key|
        !visible_fields.include?(@csv_hash[header_key])
      }
      headers
    end

    def visible_fields
      @fields ||= export_customer_fields(@type).collect {|key| key[:value] }
    end

    def email_params
      { user: User.current, domain: @portal_url, type: @type }
    end

end
