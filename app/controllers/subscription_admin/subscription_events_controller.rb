class SubscriptionAdmin::SubscriptionEventsController < ApplicationController

  include ModelControllerMethods
  include AdminControllerMethods
  include Subscription::Events::ControllerMethods
  include Subscription::Events::Constants
  
  before_filter :set_selected_tab

  helper_method :handle_nil


  def index
    @events = SubscriptionEvent.events_for_last_30_days
    @events.merge!(total_upgardes_and_downgrades)

    @revenue = SubscriptionEvent.revenue_for_last_30_days
    @revenue.merge!(revenue_details)
    
    monthly_events_info(params[:date]) unless params[:date].blank?
    monthly_revenue_info(params[:date]) unless params[:date].blank?
  end

  def handle_nil(value)
    (value.blank?)? 0 : value
  end


  private

    #Upgrades & downgrades
    def total_upgardes_and_downgrades
      {
        :upgrades => count_events(METRICS[:upgrades]),
        :downgrades => count_events(METRICS[:downgrades])
      }
    end

    def count_events(range)
      @events.inject(0) { |count, (k,v)| count += 1 if range.include?(k); count }
    end

    #Revenue Metrics
    def revenue_details     
      {
        :cmrr => calculate_revenue(METRICS[:cmrr]),
        :upgrades => calculate_revenue(METRICS[:upgrades]),
        :downgrades => calculate_revenue(METRICS[:downgrades])
      }
    end

    def calculate_revenue(range)
      @revenue.inject(0) { |sum, (k,v)| sum += v.to_i if range.include?(k); sum }
    end

    #Monthly Events Count
    def monthly_events_info(date)
      @events_count = event_stats(CODES, date) 
      @upgrades_count = event_stats(UPGRADES, date)
      @downgrades_count = event_stats(DOWNGRADES, date)
    end

    #Monthly Revenue
    def monthly_revenue_info(date)
      @metrics = overall_revenue(METRICS, date)
      @events_revenue = revenue_stats(CODES, date)
      @upgrades_revenue = revenue_stats(UPGRADES, date)
      @downgrades_revenue = revenue_stats(DOWNGRADES, date)
    end                                        

    def set_selected_tab
      @selected_tab = :events
    end
end