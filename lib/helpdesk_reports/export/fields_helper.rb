module HelpdeskReports
  module Export
    module FieldsHelper

      include HelpdeskReports::Helper::Ticket
      
      DATE_TIME_PARSE = [ :created_at, :due_by, :resolved_at, :updated_at, :first_response_time, :closed_at]
      
      def non_archive_tickets(ticket_ids)
        tickets = []
        Account.current.tickets.includes(ticket_associations_include).where(id: ticket_ids).find_in_batches(:batch_size => 300) do |tkts|
          tickets << tkts
        end
        tickets.flatten
      end
      
      def archive_tickets(ticket_ids)
        tickets = []
        Account.current.archive_tickets.includes(archive_associations_include).where(id: ticket_ids).find_in_batches(:batch_size => 300) do |tkts|
          tickets << tkts
        end
        tickets.flatten
      end
      
      def ticket_associations_include
        [ {:flexifield => [:flexifield_def]}, {:requester => [:company] }, :schema_less_ticket, :ticket_status, :group, :responder, :tags ]
      end
      
      def archive_associations_include
        [ {:flexifield => [:flexifield_def]}, {:requester => [:company] }, :archive_ticket_association, :ticket_status, :group, :responder, :tags]
      end

      def generate_ticket_data(list_of_tickets, archive_status)
        records = []
        custom_field_names = Account.current.ticket_fields.custom_fields.map(&:name)
        date_format = Account.current.date_type(:short_day_separated)

        list_of_tickets.each do |item|
          record = []
          headers.each do |val|
            data = archive_status ? fetch_field_value(item, val) : item.send(val)
            if data.present?
              if DATE_TIME_PARSE.include?(val.to_sym)
                data = parse_date(data)
              elsif custom_field_names.include?(val) && data.is_a?(Time)
                data = data.utc.strftime(date_format)
              end
            end
            record << escape_html(data)
          end
          records << record
        end
        records
      end

      def fetch_field_value(item, field)
        item.respond_to?(field) ? item.send(field) : item.custom_field_value(field)
      end

      def parse_date(date_time)
        date_time.strftime("%F %T")
      end

      def escape_html(val)
        ((val.blank? || val.is_a?(Integer)) ? val : CGI::unescapeHTML(val.to_s).gsub(/\s+/, " "))
      end

      def allowed_fields
        @allowed_fields ||= begin
          (report_export_fields.collect do |key|
             [key[:value]].concat( nested_fields_values(key) )
          end).flatten
        end
      end

      def nested_fields_values(key)
        return [] unless key[:type] == "nested_field"
        key[:levels].collect {|lvl| lvl[:name] }
      end

      def delete_invisible_fields
        headers = csv_hash.keys.map {|elem| elem.to_s }
        headers.delete_if{|header_key|
          !allowed_fields.include?(header_key)
        }
        headers
      end

    end
  end
end
