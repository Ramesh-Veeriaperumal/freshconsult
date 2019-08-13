class ReportExportMailer < ActionMailer::Base

  include HelpdeskReports::Constants::Export
  include EmailHelper
  def bi_report_export options ={}
    begin
      configure_email_config Account.current.primary_email_config if Account.current.primary_email_config.active?
      headers = mail_headers(options ,"Bi Report Export")

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
      @ticket_export   = options[:ticket_export].present? ? I18n.t('mailer_notifier.report_export_mailer.bi_report_export.ticket') : ''
      @selected_metric = options[:selected_metric] if options[:selected_metric]
      @filter_to_display = filter_to_display?(options[:report_type], options[:ticket_export])
      @report_name = options[:filter_name] ? "#{@report_type} report - #{options[:filter_name]}" : "#{@report_type}"
      @portal_name = options[:portal_name]

      add_log_info 'bi_report_export'

      mail(headers) do |part|
        part.text { render "bi_report_export.plain" }
        part.html { render "bi_report_export.html" }
      end.deliver
    ensure
      remove_email_config
    end
  end

  def no_report_data options = {}
    begin
      configure_email_config Account.current.primary_email_config if Account.current.primary_email_config.active?
      headers = mail_headers(options, "No Report Data")

      @user    = options[:user]
      @filters = options[:filters]
      @date_range  = options[:date_range]
      @report_label = report_name(options[:report_type])
      @filter_to_display = filter_to_display?(options[:report_type], options[:ticket_export])
      @portal_name = options[:portal_name]

      add_log_info 'no_report_data'

      mail(headers) do |part|
        part.text { render "no_report_data.plain" }
        part.html { render "no_report_data.html" }
      end.deliver
    ensure
      remove_email_config
    end
  end

  def exceeds_file_size_limit options = {}
    begin
      configure_email_config Account.current.primary_email_config if Account.current.primary_email_config.active?
      headers = mail_headers(options, "Exceeds File Size Limit")

      @user    = options[:user]
      @filters = options[:filters]
      @date_range  = options[:date_range]
      @report_type = report_name(options[:report_type])
      @filter_name = options[:filter_name]
      @portal_name = options[:portal_name]

      add_log_info 'exceeds_file_size_limit'

      mail(headers) do |part|
        part.text { render "exceeds_file_size_limit.plain" }
        part.html { render "exceeds_file_size_limit.html" }
      end.deliver
    ensure
      remove_email_config
    end
  end

  def report_export_task(email_hash = {}, options = {})
    begin
      @other_emails = email_hash[:other]
      configure_email_config Account.current.primary_email_config if Account.current.primary_email_config.active?
      headers = mail_headers(options, 'Report Export Task', email_hash)
      @date_range = options[:date_range]
      @invalid_count = options[:invalid_count]
      @task_start_time = options[:task_start_time]
      @description = options[:description]

      if options[:file_path].present?
        if @description
          attachment_file_name = "#{@description} #{Time.current.strftime("%d-%b-%y-%H:%M")}".gsub(/[-,\s+\/]/,'_').gsub(/_+/,'_').slice(0,235)
        else
          attachment_file_name = get_attachment_file_name(options[:file_path])
        end
        #encode64 to override the default '990 characters per row' limit on attached files
        attachments[attachment_file_name] = { :data=> Base64.encode64(File.read(options[:file_path])), :encoding => 'base64' }
      else
        @export_url = options[:export_url]
      end

      mail(headers) do |part|
        part.text { render "report_export_task.plain" }
        part.html { render "report_export_task.html" }
      end.deliver
    ensure
      remove_email_config
    end
  end

  private
  def mail_headers(options, n_type, email_hash = {})
    headers = {
      :subject     => mail_subject( options ),
      :to          => email_hash[:group] || options[:task_email_ids] || options[:user].email,
      :from        => Account.current.default_friendly_email,
      :bcc         => AppConfig['reports_email'],
      "Reply-to" => "",
      :sent_on   => Time.now,
      "Auto-Submitted" => "auto-generated",
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    headers.merge!(make_header(nil, nil, options[:user].present? ? options[:user].account_id : nil, n_type))
  end

  def mail_subject options
    sub = options[:email_subject] || I18n.t('mailer_notifier_subject.report_type_sub', report_name: report_name(options[:report_type]), date_range: options[:date_range])
    sub.prepend(I18n.t('mailer_notifier_subject.ticket_export')) if options[:ticket_export].present?
    sub
  end

  def report_name report_type
    REPORTS_NAME_MAPPING[report_type]
  end

  def filter_to_display? report_type, ticket_export
    ticket_export || [:agent_summary, :group_summary, :satisfaction_survey].include?(report_type)
  end

  def get_attachment_file_name file_path
    file_name_arr = file_path.split("/").last.split(/[-.]/)
    format = file_name_arr.pop
    file_name_arr.pop #removing secure random code
    file_name = file_name_arr.first.gsub(/_+/,"_").slice(0,235)
    "#{file_name}-#{file_name_arr[1..-1].join("-")}.#{format}"
  end

  def add_log_info action
    HelpdeskReports::Logger.log("export : triggering email : #{action} : account_id: #{@user.account.id}, agent_id: #{@user.id}, agent_email: #{@user.email}")
  end

end
