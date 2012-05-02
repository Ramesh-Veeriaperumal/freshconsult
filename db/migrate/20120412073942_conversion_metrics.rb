class ConversionMetrics < ActiveRecord::Migration
  def self.up
    add_column :conversion_metrics, :referrer_type, :integer
    ConversionMetric.all.each { |metric|      
      metric.update_keywords(metric.first_referrer)
      metric.update_attributes!({
        :referrer_type => metric.get_referrer_type(metric.first_referrer,true),
        :keywords => metric.keywords
        })
    }
  end

  def self.down
   remove_column :conversion_metrics, :referrer_type    
  end
end
