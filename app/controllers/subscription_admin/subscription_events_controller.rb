class SubscriptionAdmin::SubscriptionEventsController < ApplicationController

  include ModelControllerMethods
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
      @records_last_30_days = SubscriptionEvent.events

      @events_last_30_days = categorize_events(@records_last_30_days[:list])
      @upgrades_last_30_days = categorize_upgrades(@records_last_30_days[:list])
      @downgrades_last_30_days = categorize_downgrades(@records_last_30_days[:list])

      @overall_upgrades_last_30_days = SubscriptionEvent.upgrades
      @overall_downgrades_last_30_days = SubscriptionEvent.downgrades
      @cmrr_last_30_days = SubscriptionEvent.cmrr_last_30_days
    end

    def monthly_summary(date)
      date = Date.new(date["period(1i)"].to_i, date["period(2i)"].to_i)
      @records_month = SubscriptionEvent.events(date.beginning_of_month.beginning_of_day, date.end_of_month.end_of_day)

      @events_month = categorize_events(@records_month[:list])
      @upgrades_month = categorize_upgrades(@records_month[:list])
      @downgrades_month = categorize_downgrades(@records_month[:list])

      @overall_upgrades_month = SubscriptionEvent.upgrades(date.beginning_of_month.beginning_of_day, date.end_of_month.end_of_day)
      @overall_downgrades_month = SubscriptionEvent.downgrades(date.beginning_of_month.beginning_of_day, date.end_of_month.end_of_day)
      @cmrr_month = SubscriptionEvent.cmrr(date.beginning_of_month.beginning_of_day, date.end_of_month.end_of_day)
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
end