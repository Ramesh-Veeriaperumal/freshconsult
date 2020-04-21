class HyperTrail::ActivityObject::PostActivity < HyperTrail::ActivityObject::FreshdeskActivity
  ACTIVITY_TYPE = 'post'.freeze
  UNIQUE_ID = 'id'.freeze

  def activity_type
    ACTIVITY_TYPE
  end

  def unique_id
    UNIQUE_ID
  end
end
