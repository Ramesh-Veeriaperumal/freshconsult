module SurveyRuleHelperMethods

	private

	def require_survey_rule
    if current_account.custom_survey_enabled
      unless current_account.features?(:survey_links)
        flash[:notice] = survey_data[:survey_disabled_msg]
        return
      end
      survey_events = survey_data 
      rules = survey_events[:rules]
  		rules.each do |rule|
        if(rule['name'] == survey_events[:name] && rule['value'] != "--")
            flash[:notice] = survey_events[:survey_modified_msg] unless current_account.custom_surveys.active.first.choice_names.flatten.include? Integer(rule['value']) 
        end
      end
    end
	end
end