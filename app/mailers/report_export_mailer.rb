class ReportExportMailer < ActionMailer::Base

  include HelpdeskReports::Export::Constants

  def bi_report_export options ={}
    headers = mail_headers options

    headers[:subject] = "Ticket export | #{report_name(options[:report_type])} report for #{options[:date_range]}" if options[:ticket_export].present?

    options[:file_path].present? ? attachments[options[:file_path].split("/").last] = File.read(options[:file_path]) : @export_url = options[:export_url]

    @user    = options[:user]
    @filters = options[:filters]
    @date_range  = options[:date_range]
    @report_type = report_name(options[:report_type])
    @ticket_export   = options[:ticket_export].present? ? "ticket" : ""
    @selected_metric = options[:selected_metric] if options[:selected_metric]
    @filter_to_display = filter_to_display?(options[:report_type], options[:ticket_export])

    mail(headers) do |part|
      part.html { render "bi_report_export", :formats => [:html] }
    end.deliver
  end

  def no_report_data options = {}
    headers = mail_headers options

    @user    = options[:user]
    @filters = options[:filters]
    @date_range  = options[:date_range]
    @report_type = report_name(options[:report_type])
    @filter_to_display = filter_to_display?(options[:report_type], options[:ticket_export])

    mail(headers) do |part|
      part.html { render "no_report_data", :formats => [:html] }
    end.deliver
  end

  private

  def mail_headers options
    {
      :subject => "#{report_name(options[:report_type])} report for #{options[:date_range]}",
      :to      => options[:user].email,
      :from    => AppConfig['from_email'],
      "Reply-to" => "",
      :sent_on   => Time.now,
      "Auto-Submitted" => "auto-generated",
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
  end

  def report_name report_type
    REPORTS_NAME_MAPPING[report_type]
  end

  def filter_to_display? report_type, ticket_export
    ticket_export || ["agent_summary", "group_summary"].include?(report_type)
  end

end
