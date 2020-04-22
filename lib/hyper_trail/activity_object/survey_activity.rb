class HyperTrail::ActivityObject::SurveyActivity < HyperTrail::ActivityObject::FreshdeskActivity
  ACTIVITY_TYPE = 'survey'.freeze
  UNIQUE_ID = 'id'.freeze

  def activity_type
    ACTIVITY_TYPE
  end

  def unique_id
    UNIQUE_ID
  end
end
