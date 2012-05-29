class SubscriptionAdmin::ConversionMetricsController < ApplicationController
  include ModelControllerMethods
  include AdminControllerMethods
  before_filter :set_selected_tab, :initialize
  
  def index
    
    condition = {:created_at => (30.days.ago..Time.now)}
    if !params[:start_date].blank? 
      condition = ['created_at between ? and ?', "#{Time.parse(params[:start_date]).to_s(:db)}","#{Time.parse(params[:end_date]).to_s(:db)}"]
    end
          
    @conversion_metrics = ConversionMetric.find(:all, 
                                :include => [:account,:subscription], 
                                :order => "created_at desc",
                                :conditions => condition)
                                
    sql_query = "select sum(amount) as revenue, count(*) as total_users, IFNULL(referrer_type,0) as referrer_type,  case state when 'active' then case amount when 0 then 'free' else 'paid' end else 'trial' end as new_state from conversion_metrics cm, subscriptions scn where cm.account_id=scn.account_id"
    
    sql_query += " and (cm.created_at between '#{Time.parse(params[:start_date]).to_s(:db)}' and '#{Time.parse(params[:end_date]).to_s(:db)}') " unless params[:start_date].blank?
    
    sql_query += " group by referrer_type, new_state with rollup"
    @metric_summary =  ConversionMetric.find_by_sql(sql_query)

    categorize
    
    @conversion_metrics = @conversion_metrics.paginate( :page => params[:page], :per_page => 30)
    
  end
  
  protected
  
    def initialize
      
      @summary = Hash.new
      
      ConversionMetric::CATEGORIES.each_with_index do |cat,i|
        @summary[cat[0]] = {:name => ConversionMetric.get_category_string(cat[0]),:signup => 0, :trial => 0, :paid => 0, :free => 0, :revenue => 0}
      end
      
    end
    
    def categorize
        @metric_summary.each do |metric|
           fetch_report(metric)       
        end        
    end
    
    def fetch_report(metric)
      cat = metric.get_referrer_code(metric.referrer_type)
      
      if (!metric.new_state.blank? && metric.new_state.eql?('paid')) 
        @summary[cat][:revenue] = metric[:revenue].to_f 
        @summary[cat][:paid] = metric[:total_users].to_i
        @summary[:total][:revenue] += metric[:revenue].to_f 
        @summary[:total][:paid] += metric[:total_users].to_i
      end
      
      if (!metric.new_state.blank? && metric.new_state.eql?('free')) 
        @summary[cat][:free] = metric[:total_users].to_i 
        @summary[:total][:free] += metric[:total_users].to_i 
      end  
      
      if (!metric.new_state.blank? && metric.new_state.eql?('trial')) 
        @summary[cat][:trial] = metric[:total_users].to_i
        @summary[:total][:trial] += metric[:total_users].to_i
      end
      
      @summary[cat][:signup] += metric.total_users.to_i unless metric.total_users.blank? && metric.new_state.blank?
      
    end
    
    def set_selected_tab
        @selected_tab = :metrics
    end
     
end