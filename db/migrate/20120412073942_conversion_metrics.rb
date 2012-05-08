class ConversionMetrics < ActiveRecord::Migration
  def self.up
    add_column :conversion_metrics, :referrer_type, :integer
    ConversionMetric.all.each { |metric|
    begin
      metric.update_keywords(metric.first_referrer) unless metric.first_referrer.blank?
      referrer_type_val = metric.get_referrer_type(metric.first_referrer,true)
      metric.update_attributes!({
        :referrer_type =>  referrer_type_val || 8,
        :keywords => metric.keywords
        })
        rescue
                 referrer_type_val = metric.get_referrer_type(metric.first_referrer,true)
                       metric.update_attributes!({
                               :referrer_type =>  referrer_type_val || 8,
                                               })

        end
    }
  end

  def self.down
   remove_column :conversion_metrics, :referrer_type
  end
end