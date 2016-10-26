module HelpdeskReports
  module Export
    class Base
      
      include ::Export::Util
      include HelpdeskReports::Export::Utils
            
      attr_accessor :params, :report_type, :date_range, :filter_name, :file_format    

      def initialize(args, scheduled_report = false)
        args.symbolize_keys!
        set_locale
        TimeZone.set_time_zone
        
        @params      = args
        @report_type = args[:report_type].to_sym
        @date_range  = args[:date_range]
        @today       = DateTime.now.utc.strftime('%d-%m-%Y')
        @scheduled_report = scheduled_report
        @filter_name = params[:filter_name]
        @file_format = params[:file_format] || default_file_format

        params[:scheduled_report] = scheduled_report
      end

      def send_email( extra_options, file_path, export_type )
        options = {
          :user          => User.current,
          :domain        => Account.current.host,
          :report_type   => report_type,
          :date_range    => date_range,
          :filter_name   => filter_name,
          :portal_name   => params[:portal_name] || Account.current.helpdesk_name
        }
        options.merge!(extra_options) if extra_options
        
        if file_path.blank?
          @scheduled_report ? ScheduledTaskMailer.report_no_data_email(options, @scheduled_report) 
                              : ReportExportMailer.no_report_data(options)
        elsif @attachment_via_s3 && @scheduled_report #scheduled report to be sent as email-attachment only(temporary)
          ReportExportMailer.exceeds_file_size_limit(options)  
        else
          if @attachment_via_s3
            file_name = file_path.split("/").last
            options.merge!(:export_url => user_download_url(file_name,export_type)) # upload file on S3 and send download link
          else
            options.merge!(file_path: file_path) # Attach file in mail itself
          end
          @scheduled_report ? ScheduledTaskMailer.email_scheduled_report(options, @scheduled_report)
                              : ReportExportMailer.bi_report_export(options)
        end
      ensure
        FileUtils.rm_f(file_path) if file_path
      end

      def begin_rescue(&block)
        begin
          yield if block_given?
        rescue Exception => e
          Rails.logger.error {"Reports Export exception for #{Account.current.id} : #{e.inspect}\n #{e.backtrace.join("\n")}"}
          NewRelic::Agent.notice_error(e)
          subj_txt = "Helpkit - Error | Reports Export exception for #{Account.current.id}"
          message  = "#{e.inspect}\n #{e.backtrace.join("\n")}"
          DevNotification.publish(SNS["reports_notification_topic"], subj_txt, message)
        end
      end

      private
        def user_download_url file_name, export_type
          "#{Account.current.full_url}/reports/v2/download_file/#{export_type}/#{@today}/#{file_name}"
        end

        def default_file_format
          [:agent_summary, :group_summary, :satisfaction_survey].include?(report_type) ? 'csv' : 'pdf'
        end
        
    end
  end
end