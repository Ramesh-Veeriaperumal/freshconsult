class Fdadmin::SubscriptionEventsController < Fdadmin::DevopsMainController
	
	include Fdadmin::Subscription::EventsControllerMethods
  include Subscription::Events::Constants
  include Fdadmin::Subscription::EventsConstants

	def current_month_summary
		summary = {}
    last_30_days_summary
    summary[:events] = fetch_events_data
		summary[:revenue] = fetch_revenue_data
		respond_to do |format|
			format.json do 
				render :json => summary
			end
		end
	end

  def custom_month
    summary = {}
    monthly_summary(params[:date])
    summary[:revenue] = fetch_custom_revenue
    summary[:accounts_count] = calculate_event_count
    respond_to do |format|
      format.json do 
        render :json => summary
      end
    end
  end

  def export_to_csv
    events_id = []
    monthly_summary(params[:date])
    case params[:event_type]
    when "upgrades"
      @upgrades_month[params[:category].to_sym].each do |i|
        events_id << i['id']
      end
    when "downgrades"
      @downgrades_month[params[:category].to_sym].each do |i|
        events_id << i['id']
      end
    else
      @events_month[params[:category].to_sym].each do |i|
        events_id << i['id']
      end
    end
    email_csv(generate_csv(events_id))
    respond_to do |format|
      format.json do
        render :json => {:status => "success"}
      end
    end
  end

	private
  def cumulative_count(&block)
    count = 0
    Sharding.run_on_all_slaves(&block).each { |result| count+=result }
    count
  end

	def handle_nil(value)
    (value.blank?)? 0.0 : value
  end

	def last_30_days_summary  
    @records_last_30_days = cumilative_hash(Sharding.run_on_all_slaves { SubscriptionEvent.events })
    @events_last_30_days = categorize_events(@records_last_30_days[:list])
    @upgrades_last_30_days = categorize_upgrades(@records_last_30_days[:list])
    @downgrades_last_30_days = categorize_downgrades(@records_last_30_days[:list])
    @overall_upgrades_last_30_days = cumilative_hash(Sharding.run_on_all_slaves { SubscriptionEvent.upgrades })
    @overall_downgrades_last_30_days = cumilative_hash(Sharding.run_on_all_slaves {SubscriptionEvent.downgrades })
    @cmrr_last_30_days = cumulative_count {SubscriptionEvent.cmrr_last_30_days}
  end

  def monthly_summary(date)
    date = Date.new(date["period(1i)"].to_i, date["period(2i)"].to_i)
    @records_month = cumilative_hash(Sharding.run_on_all_slaves {SubscriptionEvent.events(date.beginning_of_month.beginning_of_day, date.end_of_month.end_of_day)})
    @events_month = categorize_events(@records_month[:list])
    @upgrades_month = categorize_upgrades(@records_month[:list])
    @downgrades_month = categorize_downgrades(@records_month[:list])
    @overall_upgrades_month = cumilative_hash(Sharding.run_on_all_slaves {SubscriptionEvent.upgrades(date.beginning_of_month.beginning_of_day, date.end_of_month.end_of_day)})
    @overall_downgrades_month = cumilative_hash(Sharding.run_on_all_slaves {SubscriptionEvent.downgrades(date.beginning_of_month.beginning_of_day, date.end_of_month.end_of_day)})
    @cmrr_month = cumulative_count {SubscriptionEvent.cmrr(date.beginning_of_month.beginning_of_day, date.end_of_month.end_of_day)}
  end

	def categorize_events(events)
    CODES.inject({}) { |h, (k, v)| h[k] = build_category(events, v); h }
  end

  def categorize_upgrades(events)
    UPGRADES.inject({}) { |h, (k, v)| h[k] = build_category(events, v); h }
  end     

  def categorize_downgrades(events)
    DOWNGRADES.inject({}) { |h, (k, v)| h[k] = build_category(events, v); h }
  end     

  def build_category(events, code)
    events.inject([]) { |category, event| category.push(event) if event.code.eql?(code); category }
  end         

   def cumilative_hash(results)
      n_h = {}
      results.each do |h|
        h.each do |k,v|
          if n_h.has_key?(k)
            v.is_a?(Hash) ? (n_h[k] = n_h[k].merge(v) {|k,f,s|  f + s }) : (n_h[k] = n_h[k] + v)   
          else
            n_h[k] = v
          end
        end
      end
      n_h
   end

   def fetch_events_data
   	return { :free => @events_last_30_days[:free].size,
   					 :affiliates => @events_last_30_days[:affiliates].size,
						 :paid => @events_last_30_days[:paid].size,
						 :free_to_paid => @events_last_30_days[:free_to_paid].size,
						 :upgrades => @overall_upgrades_last_30_days[:list].size,
						 :downgrades => @overall_downgrades_last_30_days[:list].size,
						 :deleted => @events_last_30_days[:deleted].size
					 }
   end

   def fetch_revenue_data
    actual_revenue_current = @cmrr_last_30_days - handle_nil(@overall_downgrades_last_30_days[:revenue]).abs - handle_nil(@records_last_30_days[:revenue][CODES[:deleted]])
    return { :cmrr => @cmrr_last_30_days,
             :monthly_revenue => actual_revenue_current,
             :affiliates => handle_nil(@records_last_30_days[:revenue][CODES[:affiliates]]),
             :paid => handle_nil(@records_last_30_days[:revenue][CODES[:paid]]),
             :free_to_paid => handle_nil(@records_last_30_days[:revenue][CODES[:free_to_paid]]),
             :upgrades => handle_nil(@overall_upgrades_last_30_days[:revenue]),
             :downgrades => handle_nil(@overall_downgrades_last_30_days[:revenue]).abs,
             :deleted => handle_nil(@records_last_30_days[:revenue][CODES[:deleted]])
           }
   end

   def fetch_custom_revenue
    actual_revenue_custom = @cmrr_month - handle_nil(@overall_downgrades_month[:revenue]).abs - handle_nil(@records_month[:revenue][CODES[:deleted]]).abs
    revenue = @records_month[:revenue]
    return {
    :additional_cmrr => @cmrr_month,
    :actual_revenue => actual_revenue_custom,
    :affiliates => handle_nil(revenue[CODES[:affiliates]]),
    :paid => handle_nil(revenue[CODES[:paid]]),
    :free_to_paid => handle_nil(revenue[CODES[:free_to_paid]]),
    :overall_upgrade => handle_nil(@overall_upgrades_month[:revenue]),
    :overall_downgrade => handle_nil(@overall_downgrades_month[:revenue]).abs,
    :deleted => handle_nil(revenue[CODES[:deleted]]).abs
    }
   end

   def calculate_event_count
    accounts_count = {:events => {},:deleted_event => {},:upgrades => {}, :downgrades => {}}
    SUBSCRIPTION_EVENTS.map { |record| accounts_count[:events].merge!({record[0].to_sym => @events_month[record[0]].count }) }.first
    SUBSCRIPTION_DELETED_EVENT.map { |record| accounts_count[:deleted_event].merge!({record[0].to_sym => @events_month[:deleted].count }) }.first
    SUBSCRIPTION_UPGRADES.map { |record| accounts_count[:upgrades].merge!({record[0].to_sym => @upgrades_month[record[0]].count }) }.first
    SUBSCRIPTION_DOWNGRADES.map { |record| accounts_count[:downgrades].merge!({record[0].to_sym => @downgrades_month[record[0]].count }) }.first
    return accounts_count
   end

end
