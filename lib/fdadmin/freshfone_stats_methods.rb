module Fdadmin::FreshfoneStatsMethods

  def account
    @account ||= Account.find_by_id(params[:account_id])     
  end

  def generate_email(list,csv_columns)
    if list.blank?
      render :json => {:empty => true} 
    else
      csv_string = generate_csv(list,csv_columns)  
      email_csv(csv_string,params)
      render :json => {:status => true}
    end 
  end

  def generate_csv(full_list,csv_columns)
    csv_string = CSVBridge.generate do |csv|
      csv << csv_columns
      list_length = full_list.length - 1
      (0..list_length).each do |index|
        csv<< full_list[index] 
      end
    end
  end

  def email_csv(csv_string, mail_params)
    FreshopsMailer.freshfone_stats_summary_csv(mail_params,csv_string)
  end

  def cumulative_result(resultset, total_result = [])
    resultset.each do |results|
      results.each do |result|
        total_result << result
      end
    end
    total_result
  end
end