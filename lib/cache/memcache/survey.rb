module Cache::Memcache::Survey
  
  include MemcacheKeys

  def clear_custom_survey_cache
    key = ACCOUNT_CUSTOM_SURVEY % {:account_id => self.account_id}
    MemcacheKeys.delete_from_cache key
  end

  def active_survey_updated?
    active? || just_disabled?
  end
  
  def just_disabled?
    previous_changes[:active] == [1, 0]
  end

  def clear_cache
    clear_custom_survey_cache
  end

  def survey_map_cache_key
    format(SURVEY_QUESTIONS_MAP_KEY, account_id: account_id, survey_id: id)
  end

  def clear_survey_map_cache
    key = survey_map_cache_key
    delete_value_from_cache(key)
  end

  # Map of Survey Question label and column name for easy retrieval of survey_result_data values
  def survey_questions_map_from_cache
    key = survey_map_cache_key
    fetch_from_cache(key) do
      questions_map
    end
  end

  def questions_map
    qstn_map = {}
    survey_questions.map do |survey_question|
      if survey_question.default
        qstn_map['default_question'] = survey_question.column_name
      else
        qstn_map["question_#{survey_question.id}"] = survey_question.column_name
      end
    end
    qstn_map
  end
end
