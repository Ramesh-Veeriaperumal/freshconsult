class HyperTrail::DataTransformer::ActivityDataTransformer
  def initialize(activities)
    @activities = activities
  end

  def current_account
    Account.current
  end

  def current_user
    User.current
  end

  def construct_transformed_timeline_activities
    activities = @activities.select { |activity| activity[:activity][:object] && activity[:activity][:object][:type] == activity_type }
    activity_object_ids = activities.collect { |activity| activity[:activity][:object][:id] }
    all_activity_objects_from_db = load_objects(activity_object_ids)
    fetched_object_ids = all_activity_objects_from_db.keys

    filtered_activities = activities.select { |activity| fetched_object_ids.include?(activity[:activity][:object][:id]) }
    filtered_activities.map do |activity|
      id = activity[:activity][:object][:id]
      activity_object = all_activity_objects_from_db[id]
      activity[:activity][:context] = fetch_decorated_properties_for_object(activity_object)
      activity[:activity][:timestamp] = activity_object.created_at.try(:utc)
    end
  end
end
