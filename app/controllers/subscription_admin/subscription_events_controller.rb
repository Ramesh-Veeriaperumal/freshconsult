class SubscriptionAdmin::SubscriptionEventsController < ApplicationController

  include AdminControllerMethods
  include Subscription::Events::ControllerMethods
  include Subscription::Events::Constants
  
  before_filter :set_selected_tab

  helper_method :handle_nil

  def index
    # params[:date].blank? last_30_days_summary : monthly_summary(params[:date])

    if params[:date].blank? 
      last_30_days_summary
    else
      monthly_summary(params[:date])
    end
  end

  def handle_nil(value)
    (value.blank?)? 0.0 : value
  end


  private

    def last_30_days_summary  
      @records_last_30_days = cumilative_hash(Sharding.run_on_all_slaves { SubscriptionEvent.events })

      @events_last_30_days = categorize_events(@records_last_30_days[:list])
      @upgrades_last_30_days = categorize_upgrades(@records_last_30_days[:list])
      @downgrades_last_30_days = categorize_downgrades(@records_last_30_days[:list])

      @overall_upgrades_last_30_days = cumilative_hash(Sharding.run_on_all_slaves { SubscriptionEvent.upgrades })
      @overall_downgrades_last_30_days = cumilative_hash(Sharding.run_on_all_slaves {SubscriptionEvent.downgrades })
      @cmrr_last_30_days = cumilative_count {SubscriptionEvent.cmrr_last_30_days}
    end

    def monthly_summary(date)
      date = Date.new(date["period(1i)"].to_i, date["period(2i)"].to_i)
      @records_month = cumilative_hash(Sharding.run_on_all_slaves {SubscriptionEvent.events(date.beginning_of_month.beginning_of_day, date.end_of_month.end_of_day)})

      @events_month = categorize_events(@records_month[:list])
      @upgrades_month = categorize_upgrades(@records_month[:list])
      @downgrades_month = categorize_downgrades(@records_month[:list])

      @overall_upgrades_month = cumilative_hash(Sharding.run_on_all_slaves {SubscriptionEvent.upgrades(date.beginning_of_month.beginning_of_day, date.end_of_month.end_of_day)})
      @overall_downgrades_month = cumilative_hash(Sharding.run_on_all_slaves {SubscriptionEvent.downgrades(date.beginning_of_month.beginning_of_day, date.end_of_month.end_of_day)})
      @cmrr_month = cumilative_count {SubscriptionEvent.cmrr(date.beginning_of_month.beginning_of_day, date.end_of_month.end_of_day)}
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

    def set_selected_tab
      @selected_tab = :events
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
end