class Reports::Generators::PieChart
  
  
  def gen_data(value_hash)
    total_count = value_hash.fetch(:count,0)
    pie_data = []
    value_hash.fetch(:data_hash,{}).each do |key,value|
      pie_data.push({:name => key,  :y => (value.to_f/total_count.to_f) * 100.00 })
    end
    pie_data
  end
  
  def generate(value_hash,options)
    browser_data = gen_data(value_hash)
    unless browser_data.blank?
    Highchart.pie({
      :chart => {
          :renderTo => options[:chart_name],
          :margin => [-80, 10, 0, 10],
          :borderColor => 'rgba(0,0,0,0)'
        },
      :plotOptions => {
        :pie => {
          :size => '75%',
          :borderWidth => 0,
          :shadow => false,
          :dataLabels => {
            :enabled => true,
            :connectorWidth => 0,
            :distance => -25,
            :formatter => pie_label_formatter,
            :style => {
              :font => "6pt",
              :textTransform => "capitalize"
            },
          :color => '#eee'
          },
          :showInLegend => true,
        }
      },
      :legend => {
        :layout => 'horizontal',
        :align => 'center',
        :style => {
          :top => 285,
          :left => 2,
        },
        :borderWidth => 0,
        :y => 15,
        :verticalAlign => 'bottom',
        :floating => false,
        
        :labelFormatter => pie_legend_formatter,
      },
      :series => [
          {
            :type => 'pie',
            :data => browser_data
          }
        ],
        :tooltip => {
          :formatter => pie_tooltip_formatter
        },
    })
   end
 end
 
 private

 def  pie_legend_formatter 
    'function() {
       return this.name ;
     }'
 end
    
 def  pie_label_formatter 
  "function() {
     if (this.y > 5) return Math.round(this.percentage) + '<span style=\"font-size:7px\">%</span>' ;
   }"
 end
 
 def pie_tooltip_formatter  
   'function() {
      return "<strong>" + this.point.name + "</strong>: " + this.y + "%";
    }'
  end
  
end