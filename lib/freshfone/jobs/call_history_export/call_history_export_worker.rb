class Freshfone::Jobs::CallHistoryExport::CallHistoryExportWorker < Struct.new(:export_params)
  extend Resque::AroundPerform
  include ExportCsvUtil
  include Rails.application.routes.url_helpers
  include Export::Util
  EXPORT_TYPE = "call_history"

  def perform
    Rails.logger.debug "CallHistoryExport ::: Started Call History Export for #{export_params[:account_id]}"
    prepare_params
    @current_account = Account.current
    @current_account.freshfone_account.present? && @current_account.freshfone_account.active? ?
      set_current_user : raise("The user #{export_params[:account_id]} doesn't have an active freshfone account")
    begin
      check_and_create_export EXPORT_TYPE
      export_call_history
      mail_options = { :user => @current_user, :number => get_number_string, :account => @current_account,
           :domain => @current_account.host, :export_params => export_params }
      mail_options.merge!({:url => hash_url(@current_account.host)}) unless @calls.blank?
      CallHistoryMailer.deliver_call_history_export(mail_options)
    rescue Exception => e
      Rails.logger.error "CallHistoryExport ::: Exception occured while trying to export call history for #{@current_account.id} : #{e.message}\n:\n#{e.backtrace.join('\n')}"
    ensure
      Rails.logger.debug "CallHistoryExport ::: Completed call history export for #{export_params[:account_id]}"
    end
  end

  private

    def prepare_params
      export_params.symbolize_keys!
      export_params[:export_to].downcase!
      export_params[:export_to] = "xls" if export_params[:export_to].eql? "excel" # excel fix
    end

    def set_current_user
      @current_user = @current_account.users.find(export_params[:user_id])
      @current_user.make_current
      TimeZone.set_time_zone
    end

    def format
      export_params[:export_to]
    end

    def export_call_history
      run_on_slave { load_calls }
      return if @calls.empty?
      file_string = send("generate_#{format}") # generate_csv or generate_xls
      build_file file_string, EXPORT_TYPE, format
    end

    def run_on_slave(&block)
      Sharding.run_on_slave(&block)
    end

    def load_calls
      query_array = derive_query
      @calls ||= execute_query query_array
      unless @calls.empty?
        @first_call_id = @calls.first.id
        calls_ids = @calls.map { |c| c.id }
        @calls.reject! { |c| c.parent_id.present? ? !calls_ids.include?(c.parent_id) : false }
        @calls_hash = to_hash @calls
      end
    end

    def derive_query
      filter = Freshfone::Filters::CallFilter.new(Freshfone::Call)
      conditions = filter.deserialize_from_params_with_validation(export_params).sql_conditions
      conditions.first.concat(" and freshfone_calls.call_status not in (?) and freshfone_calls.freshfone_number_id in (?)")
      conditions.push(Freshfone::Call::INTERMEDIATE_CALL_STATUS, get_number_ids)
    end

    def execute_query query_array
      results = []
      @current_account.freshfone_calls.order.where(*query_array).find_in_batches(batch_size: 1000) do |batch| 
         results.push(batch)
      end
      results.flatten!
      # results.reverse! if export_params[:wf_order_type] == "desc"
      results
    end

    def to_hash activerecord_relation
      activerecord_relation.map { |phone_call| field_hash.call(phone_call) }
    end

    def all_numbers?
     export_params[:number_id].to_i == 0
    end

    def get_number_string
      all_numbers? ? 0 : @current_account.all_freshfone_numbers.find_by_id(export_params[:number_id]).number
    end

    def get_number_ids
      all_numbers? ? @current_account.all_freshfone_numbers.map { |n| n.id } : [export_params[:number_id]]
    end

    def current_number
      @current_number ||= export_params[:number_id].present? ? @current_account.all_freshfone_numbers.find_by_id(export_params[:number_id])
                     : @current_account.freshfone_numbers.first || @current_account.all_freshfone_numbers.first 
    end

    def generate_csv
      CSVBridge.generate do |csv|
        headers = field_hash
        title_row = headers.call(freshfone_call).keys
        csv << title_row
        @calls_hash.each do |phone_call|
          csv << phone_call.values
        end
      end
    end

    def generate_xls
      require 'erb'

      @xls_hash = field_hash.call(freshfone_call)
      @xls_hash.each { |key, value| @xls_hash[key] = key }
      @headers = @xls_hash.keys.map { |header| escape_html(header) }
      @records ||= []
      @calls_hash.each do |phone_call|
        values = phone_call.values
        @records << values.map { |record| escape_html(record) }
      end
      path =  "#{Rails.root}/app/views/support/tickets/export_csv.xls.erb"
      ERB.new(File.read(path)).result(binding)
    end

    def freshfone_call
      call_params = {} 
      call_params.merge!({:call_metrics => Freshfone::CallMetric.new}) if @current_account.features?(:freshfone_call_metrics)
      Freshfone::Call.new(call_params)
    end

    def field_hash 
      return Proc.new { |t_call|
        data_hash = {
          "Call ID" => t_call.id.blank? ? "-" : t_call.id - (@first_call_id - 1),
          "Customer Name" => t_call.customer.blank? ? "-" : t_call.customer_name,
          "Customer Number" => t_call.caller_number,
          "Customer Country" => t_call.caller_country.blank? ? "-" : t_call.caller_country,
          "Direction" => call_direction_class(t_call),
          "Agent Name" => agent_name_class(t_call),
          "Helpdesk Number" => t_call.freshfone_number.blank? ? "-" : t_call.freshfone_number.number,
          "Call Status" => call_status_class(t_call),
          "Transfer Count" => t_call.children_count,
          "Parent Call ID" => t_call.parent_id.blank? ? "-" : t_call.parent_id - (@first_call_id - 1),
          "Date" => t_call.created_at.to_s 
        }
        if call_metrics_enabled?(t_call)
          data_hash.merge!(data_fields_with_metrics(t_call))
        else 
          data_hash.merge!(data_fields_without_metrics(t_call))
        end
       data_hash
      }
    end

    def data_fields_with_metrics(t_call)
      {
        "In Business Hour" => business_hour_call(t_call),
        "IVR Time" =>  formated_durations(t_call.call_metrics.ivr_time),
        "Queue Time" =>  formated_durations(t_call.call_metrics.queue_wait_time),
        "Ring Time" =>  formated_durations(t_call.call_metrics.total_ringing_time),
        "Speed to Answer" => formated_durations(t_call.call_metrics.answering_speed),
        "Hold Time" =>  formated_durations(t_call.call_metrics.hold_duration),
        "Talk time (without hold time)" => formated_durations(t_call.call_metrics.talk_time),
        "After Call Work Time" =>  formated_durations(t_call.call_metrics.call_work_time),
        "Handle Time" =>  formated_durations(t_call.call_metrics.handle_time),
        "Recording Time" => t_call.call_duration.blank? ? "N/A" : formated_durations(t_call.call_duration),
        "Bill Time" => t_call.total_duration.blank? ? "N/A" : formated_durations(t_call.total_duration),
        "CallCost ($)" => t_call.call_cost.blank? ? "N/A" : t_call.call_cost.to_s,
        "Ticket ID" => t_call.notable_present? ? t_call.associated_ticket.display_id : "N/A"
      }
    end

    def data_fields_without_metrics(t_call)
      {
        "Call Duration" => t_call.call_duration.blank? ? "-" : Time.at(t_call.call_duration).utc.strftime("%H:%M:%S"),
        "CallCost ($)" => t_call.call_cost.blank? ? "-" : t_call.call_cost.to_s,
        "Ticket ID" => t_call.notable_present? ? t_call.associated_ticket.display_id : "-"
        # "Recording_url" => @current_account.host + '/' + t_call.recording_audio.attachment_url.sub(t_call.call_sid, "")
      }
    end

    def escape_html(val)
      ((val.blank? || val.is_a?(Integer)) ? val : CGI::unescapeHTML(val.to_s).gsub(/\s+/, " "))
    end

    def format_recording_url(t_call)
      @current_account.host + '/' + t_call.recording_audio.attachment_url.sub(t_call.call_sid, "")
    end

    def formated_durations(duration)
      duration_in_seconds = duration || 0
      Time.at(duration_in_seconds).utc.strftime("%H:%M:%S")
    end

    def call_direction_class(call)
      if call.ancestry.blank?
        call.incoming? ? "Incoming" : "Outgoing"
      else
        "Transfer"
      end
    end

    def agent_name_class call
      if !call.agent.blank?
        call.agent_name
      elsif !call.direct_dial_number.blank?
        call.direct_dial_number
      else
        "Helpdesk"
      end
    end

    def call_status_class(call)
      if call.blocked?
        "Blocked"
      elsif call.completed?
        "Answered"
      elsif call.voicemail?
        "Unanswered with Voicemail"
      elsif call.busy? || call.noanswer?
        call.abandon_state.present? ? abandon_state(call) :  "Unanswered"
      else 
        call.dial_call_sid.present? ? "Answered" : "Unanswered"
      end
    end

    def sorter # not called
      @calls.sort do |left, right|
        if left.parent_id.present? && right.parent_id.present?
          left.parent_id == right.parent_id ? left.id <=> right.id : left.parent_id <=> right.parent_id
        elsif right.parent_id.present?
          left.id == right.parent_id ? left.id <=> right.id : left.id <=> right.parent_id
        # elsif left.parent_id.present?
        #   left.parent_id == right.id ? left.id <=> right.id : left.parent_id <=> right.id
        else
          left.id <=> right.id
        end
      end
    end

    def abandon_state(call)
      Freshfone::Call::CALL_ABANDON_TYPE_STR_HASH[call.abandon_state]
    end

    def business_hour_call(call)
      call.business_hour_call ? "Yes" : "No"
    end

    def call_metrics_enabled?(t_call)
      @current_account.features?(:freshfone_call_metrics) && t_call.call_metrics.present?
    end
end