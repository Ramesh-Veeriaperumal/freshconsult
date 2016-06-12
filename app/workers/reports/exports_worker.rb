module Reports
  class ExportsWorker < BaseWorker
    include Sidekiq::Worker
    include HelpdeskReports::Export::Utils
    include HelpdeskReports::Export::FieldsHelper
    include HelpdeskReports::Constants::Export

    sidekiq_options :queue => :parallel_report_exports, :retry => 0, :backtrace => true

    def self.export(tickets, args)
      args.symbolize_keys!
      batch = Sidekiq::Batch.new
      merge_required = ((tickets[:non_archive].present? && tickets[:archive].present?) ||
       (tickets[:non_archive].length > 5000 || tickets[:archive].length > 5000)) ? true : false
      batch.on(:success, self, {:merge_required => merge_required, :headers => args[:headers], :options => args[:options]})
      batch.jobs do
        tickets.each do |type, ticket_bunch|
          next if ticket_bunch.empty?
          args[:type] = type
          ticket_bunch.each_slice(5000).each do |tkts|
            args[:tkts] = tkts
            if(tkts.length < 5000)
              args[:complete_export] = true if(type == :archive || tickets[:archive].empty?)
            end
            args[:batch_id] += 1
            #Passing json string because sidekiq may lose the hash while storing & retrieving from redis
            perform_async(args.to_json)
          end
        end
      end
    end

    def perform(args)
      args = JSON.parse(args).symbolize_keys!
      options = args[:options].symbolize_keys
      run_on_account_scope(options[:account_id]) { set_current_account_and_user(options[:account_id], options[:user_id]) }
      ticket_data = CSVBridge.generate do |csv|
        csv << args[:headers]
        fetch_tickets_data(csv, args[:keys], args[:tkts], args[:type])
      end
      if args[:complete_export]
        ticket_data << I18n.t('helpdesk_reports.export_exceeds_row_limit_msg', :row_max_limit => options[:csv_row_limit]) if options[:exceeds_limit]
        if args[:batch_id] == 1
          build_file_and_email(ticket_data, TYPES[:csv], options)
          return
        end
      end
      generate_dir("#{options[:export_id]}") unless dir_exists?("#{options[:export_id]}")
      upload_batch_file(options[:export_id], args[:batch_id], ticket_data, TYPES[:csv])
    end

    def on_success(status, args = {})
      args.symbolize_keys!
      if args[:merge_required]
        options = args[:options].symbolize_keys
        run_on_account_scope(options[:account_id]) { set_current_account_and_user(options[:account_id], options[:user_id]) }
        merge_batch_files_and_email(args[:headers], options)
      else
        return
      end
    end

    private

    def run_on_account_scope(account_id)
      Sharding.select_shard_of(account_id) do
        yield if block_given?
      end
    end

    def set_current_account_and_user(account_id, user_id)
      Account.find(account_id).make_current
      Account.current.all_users.find(user_id).make_current
    end

    def merge_batch_files_and_email(headers, options={})
      batch_id = 1
      data = CSVBridge.generate do |csv|
        csv << headers
        loop do
          append_batch_content_to_csv(csv, options[:export_id], "batch_#{batch_id}.#{TYPES[:csv]}")
          batch_id += 1
          break unless batch_file_exists?(options[:export_id], "batch_#{batch_id}.#{TYPES[:csv]}")
        end
      end
      build_file_and_email(data, TYPES[:csv], options)
    end

    def build_file_and_email(data, file_type, options={})
      file_path = build_file(data, file_type, options[:report_type].to_sym, TICKET_EXPORT_TYPE ,true, options[:scheduled_report])
      options.merge!(build_options_for_email(options))
      send_email( options, file_path, TICKET_EXPORT_TYPE )
    end

    def build_options_for_email(options)
      {
        :filters         => options[:select_hash],
        :ticket_export   => true,
        :selected_metric => construct_selected_metric(options[:metric_title],options[:metric_value])
      }
    end

    def send_email( extra_options, file_path, export_type )
      options = {
        :user          => User.current,
        :domain        => extra_options[:portal_url],
        :report_type   => extra_options[:report_type],
        :date_range    => extra_options[:date_range]
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
    ensure
      FileUtils.rm_f(file_path) if file_path
    end

    def construct_selected_metric( metric, values )
      value  = values.to_s.split(" : ")
      value.length == 2 ? " #{metric} ( #{value[0]} ) " : " #{metric} "
    end

    def fetch_tickets_data(tickets = [], headers, ticket_ids, type)
      tickets_data = (type == 'non_archive' ? non_archive_tickets(ticket_ids) : archive_tickets(ticket_ids))
      generate_ticket_data(tickets, headers, tickets_data, (type != 'non_archive'))
    end

	end
end