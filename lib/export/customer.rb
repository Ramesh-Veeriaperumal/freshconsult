require 'csv'
class Export::Customer
  include ExportCsvUtil
  include Rails.application.routes.url_helpers
  include Export::Util

  def initialize(csv_hash, portal_url, type)
    @csv_hash = csv_hash
    @items = Account.current.send(type.pluralize)
    @portal_url = portal_url
    @type = type
  end

  def export_data
    csv_string = ""
    @headers = delete_invisible_fields

    unless @csv_hash.blank?
      csv_string = CSVBridge.generate do |csv|
        csv << @headers
        map_csv csv
      end
    end

    check_and_create_export @type
    build_file(csv_string, @type)
    
    DataExportMailer.deliver_customer_export({
      :user   => User.current, 
      :domain => @portal_url,
      :url    => hash_url(@portal_url),
      :type   => @type
    })
  rescue => e
    NewRelic::Agent.notice_error(e)
    puts "Error  ::#{e.message}\n#{e.backtrace.join("\n")}"
    @data_export.failure!(e.message + "\n" + e.backtrace.join("\n"))
  end

  private

    def map_csv csv
      @items.each do |record|
        csv_data = []
        @headers.each do |val|
          csv_data << record.send(@csv_hash[val]) if record.respond_to?(@csv_hash[val])
        end
        csv << csv_data if csv_data.any?
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

end