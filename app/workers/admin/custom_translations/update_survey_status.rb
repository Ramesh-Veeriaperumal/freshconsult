class Admin::CustomTranslations::UpdateSurveyStatus < BaseWorker
  sidekiq_options queue: :custom_translations_update_survey_status, retry: 0, failures: :exhausted

  attr_accessor :status

  def perform(args)
    args.symbolize_keys!
    account = Account.current
    survey_id = args[:survey_id]
    survey_was = args[:survey_was]
    custom_survey = account.custom_surveys.find_by_id(survey_id)
    return if custom_survey.nil?
    survey_is = custom_survey.as_api_response(:custom_translation).stringify_keys

    set_status(:translated)

    custom_translations = custom_survey.custom_translations.where("status != #{CustomTranslation::SURVEY_STATUS[:outdated]}")
    return if custom_translations.blank?

    check_survey_outdated(survey_was, survey_is)

    if status == CustomTranslation::SURVEY_STATUS[:outdated]
      custom_translations.each do |ct|
        ct.update_attributes(:status => CustomTranslation::SURVEY_STATUS[:outdated])
      end
    else
      custom_translations.each do |ct|
        set_status(:translated)
        check_survey_incomplete(survey_is, ct.translations)
        if ct.status != status
          ct.status = status
          ct.save!
        end
      end
    end
  rescue StandardError => e
    NewRelic::Agent.notice_error(e, description: 'Custom Translation Status Update failed while processing outdated surveys')
    Rails.logger.error("Custom Translation Status Update failure: Survey ID: #{survey_id}")
  end

  private

    def check_survey_outdated(survey_was, survey_is)
      survey_is.each_key do |key|
        if survey_is[key].is_a?(Hash)
          prev_hash = survey_was && survey_was[key].present? ? survey_was[key] : {}
          check_survey_outdated(prev_hash, survey_is[key].stringify_keys) if prev_hash.present?
        elsif survey_is[key] && survey_was[key] && survey_is[key] != survey_was[key]
          set_status(:outdated)
        end
      end
    end

    def check_survey_incomplete(survey_is, custom_translations)
      survey_is.each_key do |key|
        if survey_is[key].is_a?(Hash)
          ct_hash = custom_translations && custom_translations[key].present? ? custom_translations[key] : {}
          if ct_hash.present?
            check_survey_incomplete(survey_is[key], ct_hash)
          else
            set_status(:incomplete)
          end
        elsif custom_translations[key].blank?
          set_status(:incomplete)
        end
      end
    end

    def set_status(s)
      @status = CustomTranslation::SURVEY_STATUS[s]
    end
end
