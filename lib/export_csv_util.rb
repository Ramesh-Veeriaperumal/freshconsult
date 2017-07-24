# encoding: utf-8
require 'csv'
module ExportCsvUtil
  include Helpdesk::TicketModelExtension
  DATE_TIME_PARSE = [ :created_at, :due_by, :resolved_at, :updated_at, :first_response_time, :closed_at]

  ALL_TEXT_FIELDS = [:default_description, :default_note, :default_address, :custom_paragraph]

  CONTACT         = "contact"

  DEFAULT_SELECTED_FIELDS = {
    CONTACT: [:default_email, :default_phone],
    COMPANY: []
  }

  REJECTED_FIELDS = {
    CONTACT: [:default_company_name],
    COMPANY: []
  }

  def set_date_filter
   if !(params[:date_filter].to_i == TicketConstants::CREATED_BY_KEYS_BY_TOKEN[:custom_filter])
    params[:start_date] = params[:date_filter].to_i.days.ago.beginning_of_day.to_s(:db)
    params[:end_date] = Time.now.end_of_day.to_s(:db)
  else
    params[:start_date] = Time.zone.parse(params[:start_date]).to_s(:db)
    params[:end_date] = Time.zone.parse(params[:end_date]).end_of_day.to_s(:db)
   end
  end

  def csv_date_range_in_days
    duration_in_days = (params[:end_date].to_date - params[:start_date].to_date).to_i
  end

  def export_fields(is_portal = false)
    flexi_fields = Account.current.ticket_fields.custom_fields(:include => :flexifield_def_entry)
    csv_headers = Helpdesk::TicketModelExtension.csv_headers 
    #Product entry
    csv_headers = csv_headers + [ {:label => I18n.t("export_data.fields.product"), :value => "product_name", :selected => false, :type => :field_type} ] if Account.current.multi_product_enabled?
    description_fields = [{:label => I18n.t("export_data.fields.description"), :value => "description", :selected => false}]
    csv_headers.insert(2,description_fields)
    csv_headers = csv_headers + flexi_fields.collect { |ff| { :label => ff.label, :label_in_portal => ff.label_in_portal, :value => ff.name, :type => ff.field_type, :selected => false, :levels => (ff.nested_levels || []) } }

    if is_portal
      vfs = visible_fields
      csv_headers.delete_if{|csv_header|
        field_name = Helpdesk::TicketModelExtension.field_name csv_header[:value]
        true unless vfs.include?(field_name)
      }
    end
    csv_headers
  end

  def ticket_export_fields(is_portal = false)
    flexi_fields = Account.current.ticket_fields.custom_fields(:include => :flexifield_def_entry)
    default_csv_headers = Helpdesk::TicketModelExtension.csv_headers

    flexi_fields , additional_flexi_fields = split_flexifields(flexi_fields)

    default_csv_headers = default_csv_headers + [ {:label => I18n.t("export_data.fields.product"), :value => "product_name", :selected => false, :type => :field_type} ] if Account.current.multi_product_enabled?
    default_csv_headers = default_csv_headers + generate_headers(flexi_fields)

    additional_csv_headers = [{:label => I18n.t("export_data.fields.description"), :value => "description", :selected => false}]
    additional_csv_headers = additional_csv_headers + generate_headers(additional_flexi_fields)

    if is_portal
      vfs = visible_fields
      default_csv_headers.delete_if{|default_csv_header|
        field_name = Helpdesk::TicketModelExtension.field_name default_csv_header[:value]
        true unless vfs.include?(field_name)
      }
    end
    [default_csv_headers, additional_csv_headers]
  end

  def ticket_export_fields_without_customer
    flexi_fields = Account.current.ticket_fields.custom_fields(:include => :flexifield_def_entry)
    default_csv_headers = Helpdesk::TicketModelExtension.ticket_csv_headers

    flexi_fields , additional_flexi_fields = split_flexifields(flexi_fields)

    default_csv_headers = default_csv_headers + [ {:label => I18n.t("export_data.fields.product"), :value => "product_name", :selected => false, :type => :field_type} ] if Account.current.multi_product_enabled?
    default_csv_headers = default_csv_headers + generate_headers(flexi_fields)
  end

  def export_customer_fields type
    return unless ["contact", "company"].include?(type)
    custom_fields = Account.current.send("#{type}_form").send("#{type}_fields")
    custom_fields.reject!{|x| ["tag_names"].include?(x.name)} if type.eql?("contact")
    custom_fields.collect { |cf| 
            { :label => cf.label, 
              :value => cf.name, 
              :type => cf.field_type, :selected => false} }
  end

  def customer_export_fields type   
    default_fields = Helpdesk::TicketModelExtension.customer_fields(type)
    customer_fields = []
    (export_customer_fields(type) + default_fields).each do |f|
      f[:selected] = true if DEFAULT_SELECTED_FIELDS[type.upcase.to_sym].include?(f[:type])
      unless (ALL_TEXT_FIELDS.include?(f[:type]) || REJECTED_FIELDS[type.upcase.to_sym].include?(f[:type]))
        customer_fields << f
      end
    end
    customer_fields
  end

  def contact_company_export_fields type
    default_fields = Helpdesk::TicketModelExtension.customer_fields(type)
    (export_customer_fields(type) + default_fields).map { 
        |f| f[:value] unless ALL_TEXT_FIELDS.include?(f[:type])
    }.compact
  end

  def export_data(items, csv_hash, is_portal=false)
    csv_string = ""
    unless csv_hash.blank?
      csv_string = CSVBridge.generate do |csv|
        headers = delete_invisible_fields(is_portal)
        csv << headers.collect {|header| csv_hash[header]}
        tickets_data(items, headers, csv)
      end
    end
    send_data csv_string, 
            :type => 'text/csv; charset=utf-8; header=present', 
            :disposition => "attachment; filename=tickets.csv"
  end

  def export_xls(items, xls_hash, is_portal=false)
    unless xls_hash.blank?
      @xls_hash = xls_hash
      @headers = delete_invisible_fields(is_portal)
      @records = tickets_data(items, @headers)
    end
  end

  def tickets_data(items, headers, records = [])
    custom_field_names = Account.current.ticket_fields.custom_fields.map(&:name)
    date_format = Account.current.date_type(:short_day_separated)
    items.each do |item|
      record = []
      headers.each do |val|
        data = item.is_a?(Helpdesk::ArchiveTicket) ? 
                  fetch_archive_ticket_value(item, val) : item.send(val)
        if data.present?
          if DATE_TIME_PARSE.include?(val.to_sym)
            data = parse_date(data)
          elsif custom_field_names.include?(val) && data.is_a?(Time)
            data = data.utc.strftime(date_format)
          end
        end
        record << unescape_html(strip_equal(data))
      end
      records << record
    end
    records
  end

  def parse_date(date_time)
    date_time.strftime("%F %T")
  end

  def strip_equal(data)
    # To avoid formula execution in Excel - Removing any preceding =,+,- in any field
    ((data.blank? || (data.is_a? Integer)) ? data : (data.to_s.gsub(/^[@=+-]*/, "")))
  end

  def handle_operators(name)
    return if name.blank?
    return "'" + name if name.match(/^[@=+-]/).present?
    name
  end

  def unescape_html(data)
    ((data.blank? || (data.is_a? Integer)) ? data : (CGI::unescapeHTML(data.to_s)))
  end

  def delete_invisible_fields(is_portal)
    header_hash = reorder_export_params
    headers = header_hash.keys
    if is_portal
      vfs = visible_fields
      headers.delete_if{|header_key|
        field_name = Helpdesk::TicketModelExtension.field_name header_key
        true unless vfs.include?(field_name)
      }
    end
    headers
  end

  def reorder_export_params
    export_fields = params[:export_fields]
    return {} if export_fields.blank?
    ticket_fields   = default_export_fields_order.merge(custom_export_fields_order)
    params[:export_fields] = sort_fields export_fields, ticket_fields
    params[:export_fields]
  end

  def fetch_archive_ticket_value(item, val)
    item.respond_to?(val) ? item.send(val) : item.custom_field_value(val)
  end

  private

  def split_flexifields fields
    default_fields = []
    additional_fields = []
    fields.each do |field|
      if field.field_type != "custom_paragraph"
        default_fields << field
      else
        additional_fields << field
      end
    end
    [default_fields, additional_fields]
  end

  def generate_headers flexi_fields
    flexi_fields.collect { |ff| { :label => ff.label, :label_in_portal => ff.label_in_portal, :value => ff.name, :type => ff.field_type, :selected => false, :levels => (ff.nested_levels || []) } }
  end

end
