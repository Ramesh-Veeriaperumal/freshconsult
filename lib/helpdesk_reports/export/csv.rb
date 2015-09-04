module HelpdeskReports
  module Export
    class Csv < Export::Base
      
      def trigger
        file_path = generate_file_path(DATA_EXPORT_TYPE, TYPES[:csv])
        build_export_file do |objects|
          csv_string = generate_csv_string(objects)
          append_file(csv_string, file_path)        
        end
        upload_file(file_path)
        send_email
      end
      
      def generate_csv_string(objects)
        return if objects.blank?
        CSVBridge.generate do |csv|
          headers = fields_hash(objects.first).keys
          csv << headers
          objects.each do |object|
            csv << fields_hash(object).values
          end
        end
      end
      
      
    end
  end
end