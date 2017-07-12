module DashboardActivitiesTestHelper

  def get_activity_pattern(activity, user, type, content={})
    {
      'id' => activity.id,
      'object_id' => activity.notable_id,
      'object_type' => activity.notable_type,
      'title' => get_title(activity),
      'performer' => performer_type(user),
      'performed_at' => Time.at(activity.created_at.to_i).utc,
      'actions' => [{ 'type' => type, 'content' => content }]
    }
  end

  def get_title(activity)
    activity.notable.nil? ? activity.activity_data[:title] : h(activity.notable)
  end

  def performer_type(user)
    {
      'type' => 'user',
      'performer_type' => performing_user(user)
    }
  end

  def performing_user(user)
    {
      'id' => user.id,
      'name' => user.name,
      'avatar' => avatar_hash(user.avatar),
      'is_agent' => user.agent?,
      'deleted' => user.deleted
    }.merge(
      User.current.privilege?(:view_contacts) ? { 'email' => user.email } : {}
    )
  end

  def avatar_hash(avatar)
    return nil if avatar.blank?
    AttachmentDecorator.new(avatar).to_hash.merge("thumb_url" => avatar.attachment_url_for_api(true, :thumb))
  end
end