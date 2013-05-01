module Reports::HelpdeskGlanceReport
  
  include Reports::ReportFields
  include TicketConstants
  include Reports::Constants
  include Helpdesk::Ticketfields::TicketStatus
  include Reports::HelpdeskReportingQuery

  
  def fetch_activity(conditions)
    activity_data_hash, custom_dropdown_hash, nested_fields_hash, ticket_nested_fields = {}, {}, {}, {}
    columns_in_use = ACTIVITY_GROUPBY_ARRAY.clone
    columns_in_use = columns_in_use.concat(params[:reports]) unless params[:reports].blank?
    ticket_nested_fields = JSON.parse(params[:ticket_nested_fields]) unless params[:ticket_nested_fields].blank?
    columns_in_use.each do |column_name|
      #filtering out nested fields
      if ticket_nested_fields.has_key?(column_name)
        tickets_count = group_tkts_by_columns(conditions,{:column_name => column_name,
         :group_by => ticket_nested_fields[column_name].join(",") })
        tickets_hash = get_nested_field_reports(tickets_count,ticket_nested_fields[column_name])
        nested_fields_hash.store(column_name,tickets_hash)
      else
        tickets_count = group_tkts_by_columns(conditions,{:column_name => column_name, 
          :group_by => column_name })
        tickets_hash = get_tickets_hash(tickets_count,column_name)
        column_name.match(/ffs\.*/) ? custom_dropdown_hash.store(column_name,tickets_hash) :
            activity_data_hash.store(column_name,tickets_hash)
      end
    end
    activity_data_hash.store('custom_fields',custom_dropdown_hash)
    activity_data_hash.store('nested_fields',nested_fields_hash)
    return activity_data_hash
  end

  def fetch_activity_reports_by(conditions, reports_by)
    activity_data_hash, custom_dropdown_hash, nested_fields_hash, ticket_nested_fields = {}, {}, {}, {}
    column_name = params[:reports_by]
    ticket_nested_fields = JSON.parse(params[:ticket_nested_fields]) unless params[:ticket_nested_fields].blank?
    if ticket_nested_fields.has_key?(column_name)
      tickets_count = group_tkts_by_columns(conditions,{:column_name => column_name,
       :group_by => ticket_nested_fields[column_name].join(",") })
      tickets_hash = get_nested_field_reports(tickets_count,ticket_nested_fields[column_name])
      activity_data_hash.store('data',tickets_hash)
      activity_data_hash.store('label',column_name)
      activity_data_hash.store('chart_id','nested_fields_container')
    else
      tickets_count = group_tkts_by_columns(conditions,{:column_name => column_name, 
        :group_by => column_name })
      tickets_hash = get_tickets_hash(tickets_count,column_name)
      activity_data_hash.store('data',tickets_hash)
      activity_data_hash.store('label',column_name)
      column_name.eql?('source') ? activity_data_hash.store('chart_id','source_container') : activity_data_hash.store('chart_id','pie_chart_container')
    end
    return activity_data_hash
  end

  def get_tickets_hash(tickets_count,column_name)
    tot_count, tickets_hash = 0, {}
    tickets_count.each do |ticket|
      tot_count += ticket["count"].to_i      
      case column_name
        when "source"
          tickets_hash.store(TicketConstants.source_list[ticket["#{column_name}"].to_i],
            {:count => ticket["count"],
             :name => TicketConstants.source_list[ticket["#{column_name}"].to_i]})
        when "priority"
          tickets_hash.store(TicketConstants.priority_list[ticket["#{column_name}"].to_i],
            {:count => ticket["count"],
             :name => TicketConstants.priority_list[ticket["#{column_name}"].to_i],
             :color => TicketConstants::PRIORITY_COLOR_BY_KEY[ticket["#{column_name}"].to_i]})
        else
          tickets_hash.store(ticket["#{column_name}"],
            {:count => ticket["count"], :name => ticket["#{column_name}"]})
        end
    end
    tickets_hash = calculate_percentage_for_columns(column_name,tickets_hash,tot_count)
    return tickets_hash
  end

  def get_nested_field_reports(nested_data,column_names = [])
    column_width = 60 # Default width of the category column in the chart. Calculated based on length of category-string
    data_arr = [] # data passed to the chart
    xaxis_arr =[] # categories passed to the chart
    top_level_data, second_vs_first, count=[], {}, 0
    tot_count = get_total_data_count(nested_data)
    nested_data.each do |data|
      next unless data
      value = data[column_names[0]]
      next unless value
      unless top_level_data.include?(value)
        top_level_data.push(value)

        count = get_data_count(value,column_names[0],nested_data,nil,nil)
        percentage = tot_count == 0 ? 0 : count.to_i/tot_count.to_i * 100

        data_arr.push({:y=>0}) #to add the space b/w two categories in the chart
        xaxis_arr.push('')#to add the empty category 

        xaxis_arr.push(value)
        column_width = (value.length * 8) if((value.length * 8) > 60 && column_width< (value.length * 8))
        data_arr.push({:name=>value,:y=>sprintf( "%0.02f",percentage).to_f,:count=>count,
          :color=>'#AA4643',:borderColor=>'white',:borderWidth=>1})
      end

      #Adding the second level data
      value = data[column_names[1]]
      next unless value
      count = get_data_count(value,column_names[1],nested_data,column_names[0],data[column_names[0]])
      percentage = tot_count == 0 ? 0 : count.to_i/tot_count.to_i * 100
      if((second_vs_first[value] != data[column_names[0]]))
          second_vs_first[value] = data[column_names[0]]
          xaxis_arr.push(value)
          column_width = (value.length * 8) if((value.length * 8) > 60 && column_width< (value.length * 8))
          data_arr.push({:name=>value,:y=>sprintf( "%0.02f",percentage).to_f,:count=>count,:color=>'#89A54E',:borderColor=>'white',:borderWidth=>1})
      end

      #Adding third level data. No check as the queried data is grouped by all 3 cols so data is unique.
      next if(column_names.length == 2) #Last level can be left blank
      value = data[column_names[2]]
      next unless value
      count = data["count"]
      percentage = tot_count == 0 ? 0 : count.to_i/tot_count.to_i * 100
      xaxis_arr.push(value)  
      column_width = (value.length * 8) if((value.length * 8) > 60 && column_width< (value.length * 8))
      data_arr.push({:name=>value,:y=>sprintf( "%0.02f",percentage).to_f,:count=>count,:color=>'#4572A7',:borderColor=>'white',:borderWidth=>1})
    end
    column_width = 100 if(column_width>100)
    {:xaxis_arr => xaxis_arr, :chartData=>data_arr,:column_width=>column_width}
  end

  def get_data_count(value,column,nested_data,group_column,group_value)
    count = 0
    nested_data.each do |data|
      next unless data
        unless group_column.blank?
          count += data["count"].to_i if((value == data[column]) && group_value == data[group_column])
        else
          count += data["count"].to_i if(value == data[column])
        end
    end
    count
  end

  #Method to calculate the total count 
  def get_total_data_count(nested_data)
    total_count = 0
    nested_data.each {|data| total_count += data["count"].to_i }
    total_count
  end

  def calculate_percentage_for_columns(column_name,tickets_hash,tkts_count)
    new_val_hash = {}
    new_val_arr = []
    tickets_hash.each do |key,val_hash|
      val_per  = (val_hash.fetch(:count).to_f/tkts_count.to_f) * 100
      case column_name
        when "source"
          val_hash.store(:data,[].push({:y => sprintf( "%0.02f", val_per).to_f, :count => val_hash.fetch(:count)}))
        else
          val_hash.store(:y,sprintf( "%0.02f", val_per).to_f)
      end
      new_val_hash.store(key,val_hash)
      new_val_arr.push(new_val_hash.fetch(key))
    end
    new_val_arr
  end

end