class ReportExportMailer < ActionMailer::Base

  include HelpdeskReports::Constants::Export

  def bi_report_export options ={}
    headers = mail_headers options

    if options[:file_path].present?
      attachment_file_name = get_attachment_file_name(options[:file_path])
      #encode64 to override the default '990 characters per row' limit on attached files
      attachments[attachment_file_name] = { :data=> Base64.encode64(File.read(options[:file_path])), :encoding => 'base64' }
    else
      @export_url = options[:export_url]
    end

    @user    = options[:user]
    @filters = options[:filters]
    @date_range  = options[:date_range]
    @report_label = report_name(options[:report_type])
    @filter_name = options[:filter_name]
    @ticket_export   = options[:ticket_export].present? ? "ticket" : ""
    @selected_metric = options[:selected_metric] if options[:selected_metric]
    @filter_to_display = filter_to_display?(options[:report_type], options[:ticket_export])
    @report_name = options[:filter_name] ? "#{@report_type} report - #{options[:filter_name]}" : "#{@report_type}"

    mail(headers) do |part|
      part.text { render "bi_report_export.plain" }
      part.html { render "bi_report_export.html" }
    end.deliver
  end

  def no_report_data options = {}
    headers = mail_headers options

    @user    = options[:user]
    @filters = options[:filters]
    @date_range  = options[:date_range]
    @report_label = report_name(options[:report_type])
    @filter_to_display = filter_to_display?(options[:report_type], options[:ticket_export])

    mail(headers) do |part|
      part.text { render "no_report_data.plain" }
      part.html { render "no_report_data.html" }
    end.deliver
  end

  def exceeds_file_size_limit options = {}
    headers = mail_headers options

    @user    = options[:user]
    @filters = options[:filters]
    @date_range  = options[:date_range]
    @report_type = report_name(options[:report_type])
    @filter_name = options[:filter_name]

    mail(headers) do |part|
      part.text { render "exceeds_file_size_limit.plain" }
      part.html { render "exceeds_file_size_limit.html" }
    end.deliver
  end

  private
  def mail_headers options
    {
      :subject     => mail_subject( options ),
      :to             => options[:user].email,
      :from         => AppConfig['from_email'],
      "Reply-to" => "",
      :sent_on   => Time.now,
      "Auto-Submitted" => "auto-generated",
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
  end

  def mail_subject options
    sub = "#{report_name(options[:report_type])} report for #{options[:date_range]}"
    sub.prepend( "Ticket export | " ) if options[:ticket_export].present?
    sub
  end

  def report_name report_type
    REPORTS_NAME_MAPPING[report_type]
  end

  def filter_to_display? report_type, ticket_export
    ticket_export || [:agent_summary, :group_summary].include?(report_type)
  end

  def get_attachment_file_name file_path
    file_name_arr = file_path.split("/").last.split(/[-.]/)
    format = file_name_arr.pop
    file_name_arr.pop #removing secure random code
    file_name = file_name_arr.first.gsub(/_+/,"_").slice(0,235)
    "#{file_name}-#{file_name_arr[1..-1].join("-")}.#{format}"
  end

end
