class HyperTrail::DataTransformer::ActivityDataTransformer
  attr_accessor :object_ids, :data_map

  def initialize
    @object_ids = []
    @data_map = {}
  end

  def push(activity_object)
    activity = activity_object.activity
    activity_id = activity[:activity][:object][:id]
    @object_ids.push(activity_id)
    @data_map[activity_id] = activity_object
  end

  def current_account
    Account.current
  end

  def current_user
    User.current
  end
end
