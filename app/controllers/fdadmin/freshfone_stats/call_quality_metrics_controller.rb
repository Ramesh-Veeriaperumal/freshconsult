class Fdadmin::FreshfoneStats::CallQualityMetricsController < Fdadmin::DevopsMainController

	include Fdadmin::FreshfoneStatsMethods
	include Freshfone::CallsRedisMethods

	around_filter :select_slave_shard, :only => [:export_csv]
  before_filter :load_account, only: [:export_csv]

	def export_csv
		render :json => {:call_quality_metrics_disabled => true, :status => "error"} and return unless @account.features?(:call_quality_metrics)
	  csv_string = ""
	  csv_string = select_call_metrics_csv  if params[:export_type] == "select_call" 
	  csv_string = last_ten_calls_metrics_csv  if params[:export_type] == "last_ten_call"
	  render :json => {:empty => true, :status => "error"} if csv_string.blank?
	  unless csv_string.blank?
	    email_csv(csv_string, params) 
	    render :json => {:email_sent => true, :status => "success"}
	  end
  end

  private
   def last_ten_calls_metrics_csv
      csv_string = CSVBridge.generate do |csv|
        csv << "#{call_info_header_string}  #{metrics_summary_columns_header}"
        last_ten_call_records.each do |call|
          metrics = get_key(key call.id) || "{}"
	        JSON.parse(metrics).each do |hash|  
	          if hash[0] == "Summary"
	            csv << "#{call_info_string(call)} #{metrics_summary_columns(hash[1])}"
	          end 
	        end 
        end  
      end
    end  

    def select_call_metrics_csv
      call = @account.freshfone_calls.filter_by_dial_call_sid(params[:dial_call_sid]).first
      if call.present?
	      csv_string = CSVBridge.generate do |csv|
	        csv << call_info_header_string
	        csv << call_info_string(call)
	        csv << metrics_csv(get_key(key call.id)) 
	      end 
	    end 
    end

    def metrics_csv metrics
      csv_string = CSVBridge.generate do |csv|
        JSON.parse(metrics).each do |hash|  
          if hash[0] == "events"
            csv << metrics_events_columns_header
            events = hash[1].to_a.flatten
            i = 0
            until events[i].nil? 
              csv << metrics_events_columns(events,i)
              i+=2
            end
          elsif hash[0] == "Summary"
            csv << metrics_summary_columns_header
            csv << metrics_summary_columns(hash[1])
          end 
        end
      end
    end

    def call_info_header_string
      "Account ID, Call ID, Call SID, Dial Call SID, "
    end

    def call_info_string(call)
      "#{params[:account_id]}, #{call.id}, #{call.call_sid}, #{call.dial_call_sid}, "
    end

    def metrics_events_columns_header
      "Interval, Effective Latency, Fraction Lost, Jitter Buffer, Jitter, MOS, MOS Drop, Packets Lost, Packets Sent, Packets Received, RTT, Time, Timestamp"
    end

    def metrics_events_columns(events,i)
      "#{events[i]}, #{events[i+1]['effective_latency']}, #{events[i+1]["fraction_lost"]}, #{events[i+1]["googJitterBufferMs"]}, #{events[i+1]["jitter"]}, #{events[i+1]["mos"]}, #{events[i+1]["mos_drop"]}, #{events[i+1]["packetsLost"]}, #{events[i+1]["packetsSent"]}, #{events[i+1]["packetsReceived"]}, #{events[i+1]["rtt"]}, #{events[i+1]["time"].gsub(/,/,"")}, #{events[i+1]["timestamp"]}"
    end  

    def metrics_summary_columns_header
      "Packets Lost, Packets Received, Packets Sent, Average Jitter, Max Jitter, Average Jitter Buffer, Max Jitter Buffer, Average RTT, MAX RTT, Average MOS, Average Latency, Browser Info"
    end

    def metrics_summary_columns_selector
      ["packetsLost", "packetsReceived", "packetsSent", "average_jitter", "max_jitter", "average_googJitterBufferMs", "max_googJitterBufferMs", "average_rtt", "max_rtt", "average_mos", "average_latency", "browser_info"]
    end

    def metrics_summary_columns (summary)
      summary_csv = ""
      metrics_summary_columns_selector.each do |header|
        summary_csv << "#{summary[header].to_s.gsub(/,/,"")}, " unless summary[header].nil?
      end
      summary_csv
    end 

    def key(id) 
    	"FRESHFONE:CALL_QUALITY_METRICS:#{params[:account_id]}:#{id}"
    end

    def last_ten_call_records
      @calls ||= @account.freshfone_calls.limit(10).where("dial_call_sid is NOT NUll").order('id desc')
    end
	
end	