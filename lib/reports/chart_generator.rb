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
    line_series_data.push(prepare_data_series("Tickets Received",all_hash,{:type => "column", :color => "#00B9E6"}))
    line_series_data.push(prepare_data_series("Tickets Resolved",resolved_hash,{:type => "spline", :color => "#FF8749"}))
    line_series_data
  end
  
  def prepare_data_series(name,series_hash,options)
    data_hash = {}
    data_hash.store(:name,name)
    series_data = []
    unless series_hash.nil?
      series_hash.each do |tkt|
        series_data.push([DateTime.strptime(tkt.date, "%Y-%m-%d %H:%M:%S").to_time.to_i*1000,tkt.count.to_i])
      end
    end
    data_hash.store(:data,series_data)
    data_hash.store(:type,options[:type])
    data_hash.store(:color,options[:color])
    data_hash
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
       :colors => define_colors(column_name),
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
                :data => browser_data,
                :innerSize => '40%'
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
    Highchart.spline({
      :chart => {
          :renderTo => "freshdesk_time_line_chart",
           :marginBottom => 100,
           :marginLeft => 100,
           
        },
      :x_axis => {
         :type => 'datetime',
         :allowDecimals => false,
         :dateTimeLabelFormats => {
            :month => '%e. %b',
            :year => '%b'
         }
      },
      :y_axis => {
         :title =>  {
            :text => 'No. of Tickets'
         },
         :min => 0
      },
      :plotOptions => {
         :column => {
          :pointWidth =>  15
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
      return  Highcharts.dateFormat('%e. %b', this.x) + ': '+ this.y +' tickets';
    }"
  end
 
 # format the tooltips
  def pie_tooltip_formatter  
   'function() {
      return "<strong>" + this.point.name + "</strong>: " + this.y + " %";
    }'
  end
  
  def line_axis_formatter
    "function() {
            var monthStr = Highcharts.dateFormat('%b', this.value);
            var firstLetter = monthStr.substring(0, 1);
            return firstLetter;
        }"
  end
 
 def  pie_label_formatter 
  'function() {
      if (this.y > 15) return this.point.name;
    }'
  end
  
  def define_colors(column)
    puts column
    case column.to_s
      when "ticket_type"
        return ["'#FF8749'","'#933A8C'","'#00FFFC'","'#4051F6'"]
      when "priority"
        return ["'#49B8F9'","'#4A9D5B'","'#FF4F55'","'#FFEC6C'"]
    end    
  end
end