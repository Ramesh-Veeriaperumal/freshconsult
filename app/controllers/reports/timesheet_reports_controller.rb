class Reports::TimesheetReportsController < ApplicationController

  include Reports::TimesheetReport
  include HelpdeskReports::Helper::ControllerMethods
  include HelpdeskReports::Helper::ScheduledReports
  helper AutocompleteHelper

  before_filter :check_permission, :set_selected_tab, :set_report_type
  before_filter :report_filter_data_hash, :report_columns_hash, :only => [:index]
  before_filter :construct_csv_params,                          :only => [:export_csv]
  before_filter :validate_filters,                              :except => [:index, :time_entries_list, :delete_reports_filter]
  before_filter :build_item,                                    :only => [:index,:export_csv,:report_filter,  :generate_pdf, :time_entries_list]
  before_filter :time_sheet_list, :build_master_column_header_hash, :only => [:index,:report_filter, :generate_pdf, :time_entries_list]
  before_filter :time_sheet_for_export,                         :only => [:export_csv]
  before_filter :save_report_max_limit?,                        :only => [:save_reports_filter]
  before_filter :construct_report_filters, :schedule_allowed?,  :only => [:save_reports_filter,:update_reports_filter]

  around_filter :run_on_slave , :except => [:save_reports_filter,:update_reports_filter,:delete_reports_filter]

  helper_method :enable_schedule_report?, :custom_filters_enabled?

  attr_accessor :report_type

  def report_filter
    render :partial => "time_sheet_list"
  end

  def time_entries_list
    render json: construct_time_entries_list
  end

  def export_csv
    date_fields = [ I18n.t('helpdesk.time_sheets.createdAt'), I18n.t('helpdesk.time_sheets.date')]
    workable_fields = [I18n.t('export_data.fields.requester_name'), I18n.t('helpdesk.time_sheets.ticket_type')]
    csv_row_limit = HelpdeskReports::Constants::Export::FILE_ROW_LIMITS[:export][:csv]
    csv_hash = construct_csv_headers_hash
    csv_size = @time_sheets.size
    if (csv_size > csv_row_limit)
      @time_sheets.slice!(csv_row_limit..(csv_size - 1))
      exceeds_row_limit = true
    end
    csv_string = CSVBridge.generate do |csv|
      headers = csv_hash.keys.sort
      csv << headers
      @time_sheets.each do |record|
        record[:time_spent] += record[:timer_running]==true ? (@load_time - record[:start_time]).to_i : 0
        csv_data = []
        headers.each do |val|
          if date_fields.include?(val)
            csv_data << parse_date(record.send(csv_hash[val]))
          elsif workable_fields.include?(val)
            csv_data << strip_equal(record.workable.send(csv_hash[val]))
          else
            csv_data << strip_equal(record.send(csv_hash[val]))
          end
        end
        csv << csv_data
      end
      csv << t('helpdesk_reports.export_exceeds_row_limit_msg', :row_max_limit => csv_row_limit) if exceeds_row_limit
    end
    send_data csv_string,
      :type => 'text/csv; charset=utf-8; header=present',
      :disposition => "attachment; filename=time_sheet.csv"
  end

  def export_pdf
    params.merge!(:report_type => report_type)
    params.merge!(:portal_name => current_portal.name) if current_portal
    Reports::Export.perform_async(params)
    render json: nil, status: :ok
  end



  def save_reports_filter
    common_save_reports_filter
  end

  def update_reports_filter
    common_update_reports_filter
  end

  def delete_reports_filter
    common_delete_reports_filter
  end

  private

  def run_on_slave(&block)
    Sharding.run_on_slave(&block)
  end

  def schedule_allowed?
    if params['data_hash']['schedule_config']['enabled'] == true
      allow = enable_schedule_report? && current_user.privilege?(:export_reports)
      render json: nil, status: :ok if allow != true
    end
  end

  #copied from export csv util
  def strip_equal(data)
    # To avoid formula execution in Excel - Removing any preceding =,+,- in any field
    ((data.blank? || (data.is_a? Integer)) ? data : (data.to_s.gsub(/^[@=+-]*/, "")))
  end


end
