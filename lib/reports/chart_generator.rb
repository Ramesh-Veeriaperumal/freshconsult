module Reports::ChartGenerator
  
  TICKET_COLUMN_MAPPING = {
                            :source => TicketConstants::SOURCE_NAMES_BY_KEY,
                            :status => TicketConstants::STATUS_NAMES_BY_KEY,
                            :priority => TicketConstants::PRIORITY_NAMES_BY_KEY }
  
  def gen_pie_data(value_hash,column_name)
    pie_data = []
    value_hash.each do |key,tkt_hash|
      pie_data.push({:name => get_column_value(key,column_name),  :y => tkt_hash[:percentage].to_f })
    end
    pie_data
  end
  
  def gen_line_chart_data(all_hash,resolved_hash)
    line_series_data = []
    data_hash = {}
    data_hash.store(:name,"Tickets Received")
    series_data = []
    all_hash.each do |tkt|
      series_data.push([Date.parse(tkt.date),tkt.count.to_i])
    end
    data_hash.store(:data,series_data)
    line_series_data.push(data_hash)
    data_hash = {}
    data_hash.store(:name,"Tickets Resolved")
    series_data = []
    resolved_hash.each do |tkt|
      series_data.push([Date.parse(tkt.date),tkt.count.to_i])
    end
    data_hash.store(:data,series_data)
    line_series_data.push(data_hash)
    line_series_data
  end
  
  def get_column_value(value,column_name)
     return TICKET_COLUMN_MAPPING.fetch(column_name).send(:fetch,value.to_i) if TICKET_COLUMN_MAPPING.has_key?(column_name)
     value
  end
  
  def gen_pie_chart(value_arr,column_name)
    browser_data = gen_pie_data(value_arr,column_name)
  
  self.instance_variable_set("@#{column_name}_pie_chart", 
    Highchart.pie({
      :chart => {
          :renderTo => "#{column_name}_freshdesk_chart",
           :margin => [50, 30, 0, 30]
        },
        :plotOptions => {
          :pie => {
            :dataLabels => {
              :formatter => pie_label_formatter, 
              :style => {
                :textShadow => '#000000 1px 1px 2px'
              }
            }
          }
        },
      :series => [
            {
                :type => 'pie',
                :data => browser_data
            }
        ],
        :title => {
          :text => "Tickets by #{column_name}"
        },
        :tooltip => {
          :formatter => pie_tooltip_formatter
        },
    }))
 end 
 
 def gen_line_chart(all_hash,resolved_hash)
    line_chart_data = gen_line_chart_data(all_hash,resolved_hash)
  
  self.instance_variable_set("@freshdesk_timeline_chart", 
    Highchart.pie({
      :width => '800px',
      :chart => {
          :renderTo => "freshdesk_time_line_chart",
           :type => 'spline',
           :margin => [50, 30, 0, 30]
        },
      :xAxis => {
         :type => 'datetime',
         :dateTimeLabelFormats => { 
            :day => '%e of %b'
         }
      },
      :yAxis => {
         :title =>  {
            :text => 'No. of Tickets'
         },
         :min => 0
      },
        :plotOptions => {
          :pie => {
            :dataLabels => {
              :formatter => pie_label_formatter, 
              :style => {
                :textShadow => '#000000 1px 1px 2px'
              }
            }
          }
        },
      :series => line_chart_data,
        :title => {
          :text => "Tickets Activity"
        },
        :tooltip => {
          :formatter => line_tooltip_formatter
        },
    }))
 end
 
 def line_tooltip_formatter  
   "function() {
      return '<b>'+ this.series.name +'</b><br/>'+
               Highcharts.dateFormat('%e. %b', this.x) +': '+ this.y +' m';
    }"
  end
 
 # format the tooltips
  def pie_tooltip_formatter  
   'function() {
      return "<strong>" + this.point.name + "</strong>: " + this.y + " %";
    }'
  end
 
 def  pie_label_formatter 
  'function() {
      if (this.y > 15) return this.point.name;
    }'
  end
end