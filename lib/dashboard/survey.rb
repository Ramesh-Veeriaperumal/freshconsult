class Dashboard::Survey < Dashboard

  SURVEY_ID_NAME_MAPPING = {
    1 => "Positive",
    2 => "Neutral",
    3 => "Negative"
  }

  def initialize
    
  end

  #To do:: id to name mapping change from constant to model
  def fetch_records
    #handles = default_scoper.custom_survey_handles.where(agent_id:User.current.id).where("created_at > ?",Time.zone.now.beginning_of_month.utc).count
    results = default_scoper.custom_survey_results.where(agent_id:User.current.id).where("created_at > ?",Time.zone.now.beginning_of_month.utc).group(:rating).count
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
end
