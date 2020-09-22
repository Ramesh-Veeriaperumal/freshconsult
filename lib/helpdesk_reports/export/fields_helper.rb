module HelpdeskReports
  module Export
    module FieldsHelper

      include HelpdeskReports::Helper::Ticket
      
      DATE_TIME_PARSE = [ :created_at, :due_by, :resolved_at, :updated_at, :first_response_time, :closed_at]
      
      def non_archive_tickets(ticket_ids)
        tickets = []
        ticket_ids.each_slice(300) do |batch_ticket_ids|
          tkts = Account.current.tickets.permissible(User.current).preload(ticket_associations_include).where(id: batch_ticket_ids)
          tickets << tkts
        end
        tickets.flatten
      end
      
      def archive_tickets(ticket_ids)
        tickets = []
        ticket_ids.each_slice(300) do |batch_ticket_ids|
          tkts = Account.current.archive_tickets.permissible(User.current).includes(archive_associations_include).where(ticket_id: batch_ticket_ids)
          tickets << tkts
        end
        tickets.flatten
      end
      
      def ticket_associations_include
        [ {:flexifield => [:flexifield_def]}, :requester, :company, :schema_less_ticket, :ticket_status, :group, :responder, :tags ]
      end
      
      def archive_associations_include
        [ {:flexifield => [:flexifield_def]}, :requester, :company, :ticket_status, :group, :responder, :tags]
      end

      def generate_ticket_data(tickets = [], headers, list_of_tickets, archive_status)
        custom_field_names = Account.current.ticket_fields.custom_fields.map(&:name)
        date_format = Account.current.date_type(:short_day_separated)

        list_of_tickets.each do |item|
          record = []
          headers.each do |val|
            data = archive_status ? fetch_field_value(item, val) : item.safe_send(val)
            data = handling_deleted_field(data,val)
            if data.present?
              if DATE_TIME_PARSE.include?(val.to_sym)
                data = parse_date(data)
              elsif custom_field_names.include?(val) && data.is_a?(Time)
                data = data.utc.strftime(date_format)
              end
            end
            record << escape_html(strip_equal(data))
          end
          tickets << record
        end
      end

      def handling_deleted_field(value,field)
        case field
        when "ticket_type"
          unless value.blank?
            pick_list = Account.current.ticket_type_values.all.detect{|x| x.value == value}
            pick_list ? value : ""
          end
        else
          value
        end
      end 
      
      def fetch_field_value(item, field)
        item.respond_to?(field) ? item.safe_send(field) : item.custom_field_value(field)
      end

      def parse_date(date_time)
        date_time.respond_to?(:strftime) ? date_time.strftime("%F %T") : (Time.zone.parse(date_time).strftime("%F %T") rescue date_time)
      end

      def escape_html(val)
        ((val.blank? || val.is_a?(Integer)) ? val : CGI::unescapeHTML(val.to_s).gsub(/\s+/, " "))
      end

      def strip_equal(data)
        # To avoid formula execution in Excel - Removing any preceding =,+,- in any field
        ((data.blank? || (data.is_a? Integer)) ? data : (data.to_s.gsub(/^[=+-]*/, "")))
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
