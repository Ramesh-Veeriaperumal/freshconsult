class HyperTrail::ActivityObject::FreshdeskActivity
  attr_accessor :activity, :valid

  FRESHDESK_SOURCE = 'freshdesk'.freeze

  def initialize(activity)
    activity_content = activity[:content][activity_type]
    transfomred_activity = freshdesk_activity_hash(activity)
    transfomred_activity[:activity][:object][:id] = activity_content[unique_id]
    @activity = transfomred_activity
    @valid = false
  end

  private

    def freshdesk_activity_hash(activity)
      {
        activity: {
          name: activity[:action],
          actor: activity[:actor].symbolize_keys,
          source: freshdesk_source,
          object: {
            type: activity_type
          }
        }
      }
    end

    def freshdesk_source
      {
        name: FRESHDESK_SOURCE,
        id: Account.current.id
      }
    end
end
