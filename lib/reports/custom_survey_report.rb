module Reports::CustomSurveyReport
	include Reports::ActivityReport
  include HelpdeskReports::Constants::Export

  def start_date    
    parse_from_date.nil? ? (Time.zone.now.ago 30.day).beginning_of_day.to_s(:db) : 
        Time.zone.parse(parse_from_date).beginning_of_day.to_s(:db) 
  end
  
  def end_date
    parse_to_date.nil? ? Time.zone.now.end_of_day.to_s(:db) : 
        Time.zone.parse(parse_to_date).end_of_day.to_s(:db)
  end
  
  def parse_from_date
    unless params[:date_range].blank?
      fromDate = params[:date_range].split("-")[0]
      return fromDate if fromDate.length > 8
      return (fromDate[0,2] + "-" + fromDate[2,2] + "-" + fromDate[4,4])
    end
  end
  
  def parse_to_date
    unless params[:date_range].blank?
      dateArray = params[:date_range].split("-")
      toDate = dateArray[1] || dateArray[0]
      return toDate if toDate.length > 8
      return (toDate[0,2] + "-" + toDate[2,2] + "-" + toDate[4,4])
    end
  end
  

  def generate_survey_data

    csv_headers = SURVEY_CSV_HEADERS_1 + survey_question_labels + SURVEY_CSV_HEADERS_2

    conditions = {:start_date => start_date, :end_date => end_date, :survey_id => survey_id}

    include_array = [{:survey_remark => { :feedback => :note_body }}, 
                      :survey_result_data, :survey => [:survey_questions], 
                      :surveyable => [:requester, :company, :responder, :group ]]


    csv_row_limit = HelpdeskReports::Constants::Export::FILE_ROW_LIMITS[:export][:csv]

    csv_rows_count = 0


    csv_string = CSVBridge.generate do |csv|
      csv << csv_headers
      Account.current.custom_survey_results.permissible_survey(User.current)
             .export_data(conditions).agent_filter(agent_id)
             .group_filter(group_id)
             .find_in_batches(include: include_array) do |sr_results|
              
              size = sr_results.size
              @survey_data_exists = true if size > 0
              if (csv_rows_count+size)>csv_row_limit
                sr_results.slice!( (csv_row_limit - csv_rows_count )..(size - 1))
                @exceeds_limit = true
              end
              sr_results.each do |survey_result|
                csv_row_arr = csv_row(survey_result).compact
                csv << csv_row_arr
              end
              csv_rows_count += sr_results.size
      
      end 
      csv << [t('helpdesk_reports.export_exceeds_row_limit_msg') % {:row_max_limit => csv_row_limit}] if @exceeds_limit
    end
    csv_string
  end

  private

    def csv_row survey_result
      SURVEY_EXPORT_FIELDS.map do |method_chain|
        csv_cell(survey_result, method_chain)
      end
    end

    def csv_cell survey_result, method_chain
      if method_chain.first == :rating_text_for_custom_questions

        index = method_chain.second
        question = survey_result.survey.survey_questions[index]
        return nil if question.nil?

        rating_text_for_custom_questions survey_result, question, method_chain.last
      else
        result  = method_chain.inject(survey_result) do |evaluate_on, method_name|
          value = evaluate_on.try(method_name)
          value = (value && [:name,:body].include?(method_name)) ? value.gsub(/^(\s*[=+\-@])+/, "") : value
        end
        result = result.strftime("%F %T") if result.is_a?(Time)
        return '' if result.nil?
        result
      end
    end

    def rating_text_for_custom_questions survey_result, question, question_column
      return '' if survey_result.survey_result_data.nil?
      survey_answer = survey_result.survey_result_data.safe_send(question_column)

      face_value = (question.custom_field_choices || []).find do |choice|
        choice.face_value == survey_answer
      end.value

      return '' if face_value.nil?
      face_value
    end

    def survey_id
      params[:survey_id]
    end

    def agent_id
      params[:agent_id] if params[:agent_id] != AGENT_ALL_URL_REF
    end

    def group_id
      params[:group_id] if params[:group_id] != GROUP_ALL_URL_REF
    end

    def survey_question_labels
      labels = Account.current.custom_surveys.find(survey_id).survey_questions.pluck(:label)
      labels.shift
      labels
    end

end
