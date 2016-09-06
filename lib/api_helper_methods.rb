# encoding: utf-8
#Module for common utility API methods (DRY...)
module APIHelperMethods

  def convert_query_to_conditions(query_str)
    query =[]
    conditions = query_str.split(/\s/)
    return query if conditions.nil? || conditions.size < 3
    if ALLOWED_QUERY_COLUMNS.include?(conditions[0]) && conditions[1].match(/(like|is)/)
      value = validate(conditions[2],conditions[0])
      # Need to bring in when contact merge UI is enabled for all to check all emails of a user
      # fix_for_multiple_emails(conditions) if conditions.include?("email") 
      if conditions[0] == "customer_id" && current_account.features?(:multiple_user_companies)
        query[0] = "user_companies.company_id #{OPERATORS[conditions[1]]} ?"
      else
        query[0] = "#{conditions[0]} #{OPERATORS[conditions[1]]} ?"
      end
      query[1] = (conditions[1] == "like") ? "%#{value}%" : "#{value}"
      query
    else
      raise "Not able to parse the query."
    end
  end

  def validate(value,column)
    raise "Error : Invalid value passed" if value.match(COLUMNS_REGEX[column]).nil?
    value.match(COLUMNS_REGEX[column])[0]
  end

  def api_json_responder response,status_code
    respond_to do |format|
      format.json { render :json => response , :status => status_code }
      format.any { head status_code }
    end
  end

  # def fix_for_multiple_emails(conditions)
  #   conditions[0] = "user_emails.email"
  # end

  #white listed colums.
  ALLOWED_QUERY_COLUMNS =["email","phone","mobile","customer_id"]

  #operator conversion
  OPERATORS = {"is"=>"=","like"=>"like"}

  #add the appropriate regex here.
  COLUMNS_REGEX ={"email"=>AccountConstants::EMAIL_VALIDATOR,"phone"=>/\d+/,"mobile"=>/\d+/,"customer_id"=>/\d+/}


end