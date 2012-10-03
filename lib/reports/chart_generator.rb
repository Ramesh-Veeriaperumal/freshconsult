module Reports::ChartGenerator
  
  TICKET_COLUMN_MAPPING = {
                            "source" => TicketConstants::SOURCE_NAMES_BY_KEY,
                            "priority" => TicketConstants::PRIORITY_NAMES_BY_KEY
                          }  
                          
  def ticket_status_mapping
    Helpdesk::TicketStatus.status_names_by_key(Account.current)
  end
  
  def gen_pie_data(value_hash,column_name)
    
    sort_data = Array.new
    value_hash.each do |key,tkt_hash|
      sort_data.push([key,tkt_hash[:percentage].to_f ])
    end
    sort_data.sort! { |a, b| b.second <=> a.second }
    pie_data = []
    sort_data.each do |key,tkt_hash|
      pie_data.push({:name => get_column_value(key,column_name),  :y => tkt_hash.to_f })
    end

    pie_data
  end

  def gen_gauge_data(value,column_name)
    gauge_data = []
    gauge_data.push({:name => column_name,  :y => value.to_f.round(2) })
    gauge_data.push({:name => '__blank',  :y => (100 - value).to_f.round(2) })
    gauge_data
  end

  def gen_stacked_bar_data(value,column_name)
        
    sort_data = Array.new
    value.each do |key,tkt_hash|
      sort_data.push([key,tkt_hash[:percentage].to_f ])
    end

    sort_data.map! { |pair| [pair.first, pair.second.to_f] }
    sort_data.sort! { |a, b| a.second <=> b.second }
    
    pie_data = []
    sort_data.each do |key,tkt_hash|
     if (TicketConstants::SOURCE_NAMES_BY_KEY.has_key?(key))
        pie_data.push({:name => TicketConstants::SOURCE_NAMES_BY_KEY.fetch(key),  :data => [tkt_hash.to_f] })
     else
        pie_data.push({:name=> key,:data =>[tkt_hash.to_f] })#//TODO need to do i18n for the key 
      end
    end
    pie_data
  end


  def gen_line_chart_data(all_hash,resolved_hash)
    line_series_data = []
    line_series_data.push(prepare_data_series("Tickets Received",all_hash,{:type => "line", :color => "#418DC8"}))
    line_series_data.push(prepare_data_series("Tickets Resolved",resolved_hash,{:type => "line", :color => "#75BB55"}))
    line_series_data
  end

  def prepare_data_series(name,series_hash,options)
    data_hash = {}
    data_hash.store(:name,name)
    series_data = []
    dates_with_data = []
    unless series_hash.nil?
      series_hash.each do |tkt|
        series_data.push([DateTime.strptime(tkt.date, "%Y-%m-%d").to_time.to_i*1000, tkt.count.to_i])
        dates_with_data.push(Time.parse(tkt.date).to_i*1000)
      end
    end

    # Pushing the dates with 0 tickets
    tmp_dates_without_data = []
    this_date = Time.parse(start_date(false)).beginning_of_day
    report_end_date = Time.parse(end_date(false)).beginning_of_day
    until this_date >= report_end_date
      series_data.push([this_date.to_i*1000,0]) unless dates_with_data.include?(this_date.to_i*1000)
      tmp_dates_without_data.push([this_date.to_i*1000,0]) unless dates_with_data.include?(this_date.to_i*1000)      
      this_date = this_date.since 1.day
    end
    data_hash.store(:data,series_data)
    data_hash.store(:type,options[:type])
    data_hash.store(:color,options[:color])
    data_hash
  end
  
  def get_column_value(value,column_name)
    if TICKET_COLUMN_MAPPING.has_key?(column_name)
      return TICKET_COLUMN_MAPPING.fetch(column_name).send(:fetch,value.to_i)
    elsif("status".eql?column_name)
      ticket_status_mapping.send(:fetch,value.to_i)
    end
    value
  end
  
  def gen_pie_chart(value_arr,column_name)
    browser_data = gen_pie_data(value_arr,column_name)
    unless browser_data.blank?
    Highchart.pie({
      :chart => {
          :renderTo => "#{column_name.to_s.gsub('.', '_')}_freshdesk_chart",
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
              #:textShadow => '#333333 1px 1px 2px',
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
            :data => browser_data,
            :innerSize => '30%'
          }
        ],
        :tooltip => {
          :formatter => pie_tooltip_formatter
        },
    })
   end
  end 
  


def gen_pareto_chart(chart_name,data_arr,xaxis_arr,column_width)
return nil if data_arr.empty?
  Highchart.bar({
    :chart =>{
        :renderTo => "#{chart_name}_bar_chart",
          :margin => [10,35,50,column_width],
          :borderColor => 'rgba(0,0,0,0)',
          :height =>(data_arr.length*20 < 320)? 320 :data_arr.length*20,
          :plotBackgroundColor=>'rgba(255,255,255,0.1)',
          :backgroundColor=>'rgba(255,255,255,0.1)',
          },
           :x_axis=>{
            :reversed=>false,
            :categories=>xaxis_arr.reverse,
            :tickWidth=>0,
            :labels=>{
              :formatter => pareto_category_formatter,
                 :style=> {
                           :font=>'normal 11px Helvetica Neue, sans-serif',
                         },
               },
            },
             :y_axis=> {
              :min => 0,
              :max =>100,
              :gridLineColor=> '#cccccc',
              :gridLineDashStyle=>'dot',
                :title=> {
                    :text=> 'Percentage %',
                    :align=> 'high',
                    :style=> {
                           :font=>'normal 11px Helvetica Neue, sans-serif',
                    },
                },
                :labels=> {
                    :overflow=> 'justify',
                     :style=> {
                           :font=>'normal 11px Helvetica Neue, sans-serif',
                         },
                }
            },
             :plotOptions=> {
                :bar=> {
                    :dataLabels=> {
                        :enabled=> true,
                         :style=> {
                           :font=>'normal 11px Helvetica Neue, sans-serif',
                         },
                      :overflow=> 'justify',
                        :formatter =>  pareto_label_formatter,
                        :align => 'left',
                        :y => 0,
                    }
                },
                :series=>{
                  :groupPadding=> 0.025,
                  :pointWidth=>15,
                }
            },
            :series =>[{:data=>data_arr.reverse}],
                 :tooltip => {
                       :style=> {
                           :font=>'normal 11px Helvetica Neue, sans-serif',
                           :padding=>5,
                         },
                    :formatter =>  pareto_tooltip_formatter,
      },

  })
end


  def gen_single_stacked_bar_chart(value_arr,column_name)
    browser_data = gen_stacked_bar_data(value_arr,column_name)
    self.instance_variable_set("@#{column_name.to_s.gsub('.', '_')}_single_stacked_bar_chart",
    Highchart.bar({
      :chart => {
          :renderTo => "#{column_name.to_s.gsub('.', '_')}_freshdesk_single_stacked_bar_chart",
          :margin => [10,5,10,40],
          :borderColor => 'rgba(0,0,0,0)'
        },
      :x_axis => {
      	:categories => ['Tickets'],
        :gridLineColor => '#FFFFFF',
        :gridLineWidth => 0,
        :minorGridLineWidth => 0,
        :tickWidth => 0,
        :lineWidth => 0,
        :labels => {
          :enabled => false,
        },
      },
      :y_axis => {
        :gridLineColor => '#FFFFFF',
        :title => 'Tickets',
        :min => 0,
        :lineWidth => 0,
        :gridLineWidth => 0,
        :minorGridLineWidth => 0,
        :labels => {
          :enabled => false,
        }
      },
      :plotOptions => {
        :series => {
          :stacking => 'normal'
        },
        :bar => {
          :borderWidth => 0,
          :shadow => false,
          :dataLabels => {
            :enabled => true,
            :formatter => pie_label_formatter,
            :color => '#eee',
            :align => 'center',
            :y => 0,
          },
          :showInLegend => true,
        }
      },
      :legend => {
        :layout => 'horizontal',
        :align => 'center',
        :style => {
          :left => 40,
          :top => 75,
        },
        :borderWidth => 0,
        :y => -25,
        :reversed => true,
        :verticalAlign => 'top',
        :floating => false,
        :labelFormatter => pie_legend_formatter,
      },
      :series => browser_data,
      :tooltip => {
        :formatter => stack_bar_single_tooltip_formatter,
      },
    }))
  end 


  def gen_pie_gauge(value,column_name)
    formatted_data = gen_gauge_data(value,column_name)
    self.instance_variable_set("@#{column_name.to_s.gsub('.', '_')}_pie_gauge",
    Highchart.pie({
      :chart => {
          :renderTo => "#{column_name.to_s.gsub('.', '_')}_freshdesk_gauge",
          :borderColor => 'rgba(0,0,0,0)'
          # :backgroundColor => '#F6F6F6',
          # :margin => [0, 10, 20, 10]
        },
      :colors => define_gauge_colors(column_name),
      :plotOptions => {
        :pie => {
          :size => '100%',
          :borderWidth => 1,
          :borderColor => '#FEFEFE',
          :shadow => false,
          :dataLabels => {
            :enabled => true,
            :connectorWidth => 1,
            :distance => -49,
            :formatter => gauge_label_formatter,
            :color => '#000000',
            :style => {
              :font => '14pt "Helvetica Neue"'
            }
          },
        }
      },
      :legend => {
        :enabled => false,
      },
      :series => [
            {
                :type => 'pie',
                :data => formatted_data,
                :innerSize => '60%'
            }
        ],
        :tooltip => {
          :enabled => false,
          :formatter => gauge_tooltip_formatter
        },
    }))
 end 
 
 def gen_line_chart(all_hash,resolved_hash)
  line_chart_data = gen_line_chart_data(all_hash,resolved_hash)
  self.instance_variable_set("@freshdesk_timeline_chart", 
    Highchart.column({
      :chart => {
          :renderTo => "freshdesk_time_line_chart",
          :marginBottom => 50,
          :marginTop => 10,
          :marginLeft => 70,
          :marginRight => 30,
          :zoomType => 'x',
          :borderColor => 'rgba(0,0,0,0)'
      },
      :legend => {
        :layout => 'horizontal',
        :align => 'center',
        :style => {
          :bottom => 0,
          :top => 'auto',
          :fontWeight=> 'normal'
        },
        :y => 15,
        :verticalAlign => 'bottom',
        :floating => false,
        
      },
      :x_axis => {
         :type => 'datetime',
         :allowDecimals => false,
         :dateTimeLabelFormats => {
           :month => '%e. %b',
            :year => '%b'
         },
         :gridLineWidth => 0,
         :startOnTick => true,
         :endOnTick => true,

      },
      :y_axis => {
         :title =>  {
            :text => 'No. of Tickets'
         },
         :min => 0,
         :gridLineWidth => 1,
         :allowDecimals => false,
         :gridLineDashStyle => 'ShortDot',   
         :showFirstLabel => false
      },
      :plotOptions => {
         :column => {
           :borderWidth => 0,
           :shadow => false,
           :dataLabels => {
                :enabled => false
           },
         }
       }, 
      :series => line_chart_data,

        :tooltip => {
          :formatter => line_tooltip_formatter
        }
    }))
 end
 

 def pareto_tooltip_formatter
    "function() {
        return '<p>' + this.point.name  + '<strong> : ' +this.point.y+ '%</strong> ('+this.point.count+' tickets)</p>';
    }"
 end

 def pareto_category_formatter
  "function(){
    value = this.value;
    if(value.length > 15){
        value =value.substring(0,15);
        value =value+'...';
      }
      return value;
    }"
 end

 def pareto_label_formatter
  "function() {
     if(this.y>0)  return  this.point.y+'%' ;
   }"
 end

 def line_tooltip_formatter  
   "function() {
      return  '<strong>' + this.y +' tickets </strong> on ' + Highcharts.dateFormat('%b %e', this.x) ;
    }"
  end
 
 # format the tooltips
  def pie_tooltip_formatter  
   'function() {
      return "<strong>" + this.point.name + "</strong>: " +  Math.round(this.percentage) + "%";
    }'
  end
  
 
 # format the tooltips
  def gauge_tooltip_formatter  
   'function() {
      return this.y + " %";
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
  "function() {
     if(this.percentage > 3) return Math.round(this.percentage) + '<span style=\"font-size:7px\">%</span>' ;
    }"
  end

 def  stack_bar_single_tooltip_formatter 
  "function() {
      return '<strong>' + this.series.name  + '</strong> ' + Math.round(this.percentage,3)+ '%';
    }"
  end
  
 def  pie_legend_formatter 
  'function() {
            return this.name ;
        }'
  end

 def  gauge_label_formatter 
  'function() {
      if (this.point.name != "__blank") return Math.round(this.y) + "%" ;
    }'
  end
  
  def define_colors(column)
    case column.to_s
      # when "ticket_type"
      #   return ["'#FF8749'","'#933A8C'","'#00FFFC'","'#4051F6'"]
      when "priority"
        return ["'#0C8AAE'","'#0A9456'","'#CC5600'","'#AA4643'"]
    end    
  end

  def define_gauge_colors(column)
    case column.to_s
      when "sla"
        return ["'#0A9456'","'#CC0000'"]
      when "fcr"
        return ["'#0C8AAE'","'#CFCFCF'"]
    end    
  end
end