class Helpdesk::QnaInsight < ActiveRecord::Base
  self.primary_key = :id
  self.table_name =  "qna_insights_reports"
  belongs_to_account
  belongs_to :user

  RECENT_QUESTIONS_LIMIT = 5

  attr_protected :account_id, :user_id

  serialize :insights_config_data
  serialize :recent_questions

  # for exsting
  #   remove the older one if size is more
  #   add new hash to the array
  def update_recent_question (question)
    recent_questions_arr = recent_questions[:questions]
    recent_questions_arr.delete(question) if (recent_questions_arr.include? question)
    recent_questions_arr.shift if(recent_questions_arr.length>=RECENT_QUESTIONS_LIMIT)
    recent_questions_arr.push(question)
    recent_questions[:questions] = recent_questions_arr
    save
  end


  def get_recent_questions
    recent_questions[:questions].reverse
  end

  def get_insights_config(key = nil)
    return insights_config_data[:config][key] if key
    insights_config_data[:config]
  end

  # for exsting
  #   add / update the entry
  def update_insights_config (config_data)
    insights_config_data[:config].merge!(config_data)
    save
  end

end
