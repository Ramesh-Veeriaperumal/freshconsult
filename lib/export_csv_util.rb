module ExportCsvUtil

  def set_date_filter
   if !(params[:date_filter].to_i == TicketConstants::CREATED_BY_KEYS_BY_TOKEN[:custom_filter])
    params[:start_date] = params[:date_filter].to_i.days.ago.beginning_of_day.to_s(:db)
    params[:end_date] = Time.now.end_of_day.to_s(:db)
  else
    params[:start_date] = Date.parse(params[:start_date]).beginning_of_day.to_s(:db)
    params[:end_date] = Date.parse(params[:end_date]).end_of_day.to_s(:db)
   end
  end

  def csv_date_range_in_days
    duration_in_days = (params[:end_date].to_date - params[:start_date].to_date).to_i
  end

  def export_fields(is_portal=false)
    flexi_fields = current_account.ticket_fields.custom_fields(:include => :flexifield_def_entry)
    csv_headers = Helpdesk::TicketModelExtension.csv_headers 
    #Product entry
    csv_headers = csv_headers + [ {:label => "Product", :value => "product_name", :selected => false, :type => :field_type} ] if current_account.has_multiple_products?
    csv_headers = csv_headers + flexi_fields.collect { |ff| { :label => ff.label, :value => ff.name, :type => ff.field_type, :selected => false, :levels => (ff.nested_levels || []) } }

    if is_portal
      vfs = visible_fields
      csv_headers.delete_if{|csv_header|
        field_name = Helpdesk::TicketModelExtension.field_name csv_header[:value]
        true unless vfs.include?(field_name)
      }
    end
    csv_headers
  end

  def export_contact_fields
    [
      {:label => "Name", :value => "name", :selected => true},
      {:label => "Email",   :value => "email",    :selected => true},
      {:label => "Job Title", :value => "job_title", :selected => false},
      {:label => "Company", :value => "customer_id", :selected => false},
      {:label => "Phone", :value => "phone", :selected => false},
      {:label => "Twitter ID", :value => "twitter_id", :selected => false}
    ]
  end

  def export_contact_data(csv_hash)
    csv_string = ""
    items = current_account.contacts
    unless csv_hash.blank?
      csv_string = FasterCSV.generate do |csv|
        headers = csv_hash.keys
        csv << headers
        items.each do |record|
          csv_data = []
          headers.each do |val|
            if csv_hash[val] == "customer_id"
              (record.customer.blank?) ? csv_data << nil : csv_data << record.customer.name
            else
              csv_data << record.send(csv_hash[val])
            end
          end
          csv << csv_data if csv_data.any?
        end
      end
    end
    send_data csv_string, 
            :type => 'text/csv; charset=utf-8; header=present', 
            :disposition => "attachment; filename=contacts.csv"
  end

  def export_data(items, csv_hash, is_portal=false)
    csv_string = ""
    unless csv_hash.blank?
      csv_string = FasterCSV.generate do |csv|
        headers = csv_hash.keys.sort
        if is_portal
          vfs = visible_fields
          headers.delete_if{|header_key|
            field_name = Helpdesk::TicketModelExtension.field_name csv_hash[header_key]
            true unless vfs.include?(field_name)
          }
        end
        csv << headers
        items.each do |record|
          csv_data = []
          headers.each do |val|
            csv_data << record.send(csv_hash[val])
          end
          csv << csv_data
        end
      end
    end
    send_data csv_string, 
            :type => 'text/csv; charset=utf-8; header=present', 
            :disposition => "attachment; filename=tickets.csv"
  end
end
