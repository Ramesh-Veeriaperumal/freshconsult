class Dashboard::SurveyWidget < Dashboard

  SURVEY_ID_NAME_MAPPING = {
    1 => "Positive",
    2 => "Neutral",
    3 => "Negative"
  }

  def initialize
    
  end

  #To do:: id to name mapping change from constant to model
  def fetch_records(options = {})
    #handles = default_scoper.custom_survey_handles.where(agent_id:User.current.id).where("created_at > ?",Time.zone.now.beginning_of_month.utc).count
    filter_options = filter_by_condition(options)
    unless filter_options.nil?
      results = default_scoper.custom_survey_results.where(filter_options[:condition],filter_options[:value]).where("created_at > ?",Time.zone.now.beginning_of_month.utc).group(:rating).count
    else
      results = default_scoper.custom_survey_results.where("created_at > ?",Time.zone.now.beginning_of_month.utc).group(:rating).count
    end
    total = results.values.sum
    results_distribution = results.inject({}) do |res_hash, result|
      res_hash.merge!({SURVEY_ID_NAME_MAPPING[result.first] => ((result.last.to_f/total.to_f) * 100).round})
    end
    {:survey_responded => total, :results => results_distribution}
  end

  private
    def default_scoper
      Account.current
    end

    def filter_by_condition(options = {})
      options[:is_agent] ? agent_condition : group_condition(options[:group_id])
    end

    def agent_condition
      { condition: 'agent_id = ?', value: User.current.id }
    end

    def group_condition(group_id)
      group_id.present? ? { condition: 'group_id = ?', value: group_id } : nil
    end
end
