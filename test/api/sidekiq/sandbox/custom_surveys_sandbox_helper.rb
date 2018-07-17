module CustomSurveysSandboxHelper
  MODEL_NAME = Account.reflections["custom_surveys".to_sym].klass.new.class.name 
  ACTIONS = ['delete', 'update', 'create']

  def custom_surveys_data(account)
    all_custom_surveys_data = []
    ACTIONS.each do |action|
      all_custom_surveys_data << send("#{action}_custom_surveys_data", account)
    end
    all_custom_surveys_data.flatten
  end

  def create_custom_surveys_data(account)
    custom_survey_data = []
    3.times do
      custom_survey = create_custom_survey(account)
      custom_survey_data << custom_survey.attributes.merge("model" => MODEL_NAME, "action" => "added")
    end
    return custom_survey_data
  end

  def update_custom_surveys_data(account)
    custom_survey = account.custom_surveys.undeleted.first
    return [] unless custom_survey
    custom_survey.title_text = "modified_custom_survey"
    changed_attr = custom_survey.changes
    custom_survey.save
    return [Hash[changed_attr.map {|k,v| [k,v[1]]}].merge("id"=> custom_survey.id).merge("model" => MODEL_NAME, "action" => "modified")]
  end

  def delete_custom_surveys_data(account)
    custom_survey = account.custom_surveys.undeleted.first
    return [] unless custom_survey
    custom_survey.destroy
    return [custom_survey.attributes.merge("model" => MODEL_NAME, "action" => "deleted")]
  end

  def create_custom_survey(account)
  	options = { 
  		:title_text              =>  Faker::Lorem.sentence(3), 
  		:thanks_text             =>  Faker::Lorem.sentence(3), 
  		:comments_text           =>  Faker::Lorem.sentence(5), 
  		:feedback_response_text  =>  Faker::Lorem.sentence(6), 
  		:send_while              =>  3, 
  		:can_comment             =>  1, 
  		:active                  =>  1
  	}
  	custom_survey = account.custom_surveys.undeleted.new
  	custom_survey.store(options)
  	custom_survey
  end

end

