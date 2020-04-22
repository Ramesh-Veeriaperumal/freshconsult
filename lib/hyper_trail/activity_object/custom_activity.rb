class HyperTrail::ActivityObject::CustomActivity
  attr_accessor :activity, :valid

  CUSTOM_ACTIVITY = 'contact_custom_activity'.freeze

  def initialize(activity)
    custom_activity = activity[:content][CUSTOM_ACTIVITY]
    @activity = {
      activity: custom_activity['activity'],
      contact: custom_activity['contact']
    }
    @valid = true
  end
end
