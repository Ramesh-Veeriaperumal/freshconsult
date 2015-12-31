module HelpdeskReports
  module Export
    class Base
      
      include ::Export::Util
      include HelpdeskReports::Export::Utils
            
      attr_accessor :params, :report_type, :date_range     

      def initialize(args)
        args.symbolize_keys!

        set_current_account args[:account_id]
        set_current_user args[:user_id]
        set_locale
        TimeZone.set_time_zone
        
        @params      = args
        @report_type = args[:report_type]
        @date_range  = args[:date_range]
        @today       = DateTime.now.utc.strftime('%d-%m-%Y')
      end

      def send_email( extra_options, file_path, export_type )
        options = {
          :user          => User.current,
          :domain        => params[:portal_url],
          :report_type   => report_type,
          :date_range    => date_range
        }
        options.merge!(extra_options) if extra_options

        if file_path.blank?
          ReportExportMailer.no_report_data(options)
        else
          if @attachment_via_s3
            file_name = file_path.split("/").last
            options.merge!(:export_url => user_download_url(file_name,export_type)) # upload file on S3 and send download link
          else
            options.merge!(file_path: file_path) # Attach file in mail itself
          end
          ReportExportMailer.bi_report_export(options)
        end
      end

      def begin_rescue(&block)
        file_path = nil
        begin
          yield if block_given?
        rescue Exception => e
          NewRelic::Agent.notice_error(e)
          subj_txt = "Reports Export exception for #{Account.current.id}"
          message  = "#{e.inspect}\n #{e.backtrace.join("\n")}"
          DevNotification.publish(SNS["reports_notification_topic"], subj_txt, message)
        ensure
          FileUtils.rm_f(file_path) if file_path
        end
      end

      private
        def user_download_url file_name, export_type
          "#{Account.current.full_url}/reports/v2/download_file/#{export_type}/#{@today}/#{file_name}"
        end
        
    end
  end
end