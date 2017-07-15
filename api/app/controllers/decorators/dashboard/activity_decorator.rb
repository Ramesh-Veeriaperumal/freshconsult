class Dashboard::ActivityDecorator < ApiDecorator
  delegate :id, :description, :activity_data, :notable_type, :notable_id, :user_id, :created_at, to: :record

  SUMMARY_MAP = [
    ['tickets_status_change',                         :property_update,           nil],
    ['tickets_priority_change',                       :property_update,           nil],
    ['tickets_source_change',                         :property_update,           nil],
    ['tickets_ticket_type_change',                    :property_update,           nil],
    ['tickets_assigned_to_nobody',                    :property_update,           :responder_id],
    ['tickets_reassigned',                            :property_update,           :responder_id],
    ['tickets_assigned',                              :property_update,           :responder_id],
    ['tickets_group_change',                          :property_update,           :group],
    ['tickets_due_date_updated',                      :property_update,           :due_by],
    ['tickets_product_change',                        :property_update,           :product],
    ['tickets_deleted',                               :deleted,                   nil],
    ['tickets_restored',                              :restored,                  nil],
    ['tickets_timesheet_new',                         :timesheet_old,             :timesheet_new],
    ['tickets_timesheet_timer_started',               :timesheet_old,             :timesheet_timer_started],
    ['tickets_timesheet_timer_stopped',               :timesheet_old,             :timesheet_timer_stopped],
    ['tickets_new_ticket',                            :new_ticket,                nil],
    ['tickets_new_tracker_ticket',                    :new_tracker_ticket,        nil],
    ['tickets_new_outbound',                          :new_outbound,              nil],
    ['tickets_conversation_out_email',                :note,                      :conversation_out_email],
    ['tickets_conversation_out_email_private',        :note,                      :conversation_out_email_private],
    ['tickets_conversation_in_email',                 :note,                      :conversation_in_email],
    ['tickets_conversation_note',                     :note,                      :conversation_note],
    ['tickets_conversation_twitter',                  :note,                      :conversation_twitter],
    ['tickets_conversation_ecommerce',                :note,                      :conversation_ecommerce],
    ['tickets_execute_scenario',                      :execute_scenario,          nil],
    ['tickets_ticket_merge',                          :ticket_merge_target,       :ticket_merge_target],
    ['tickets_ticket_split',                          :ticket_split_source,       :ticket_split_source],
    ['tickets_note_split',                            :ticket_split_target,       :ticket_split_target],

    ['solutions_new_solution',                        :new_solution,              nil],
    ['solutions_new_solution_category',               :new_solution_category,     nil],
    ['solutions_new_solution_category_translation',   :new_solution_category,     nil],
    ['solutions_delete_solution_category',            :delete_solution_category,  nil],
    ['solutions_new_article',                         :new_article,               nil],
    ['solutions_new_article_translation',             :new_article,               nil],
    ['solutions_published_article',                   :article,                   :published],
    ['solutions_published_article_translation',       :article,                   :published],
    ['solutions_unpublished_article',                 :article,                   :unpublished],
    ['solutions_unpublished_article_translation',     :article,                   :unpublished],
    ['solutions_delete_article',                      :delete_article,            nil],
    ['solutions_new_folder',                          :new_folder,                nil],
    ['solutions_new_folder_translation',              :new_folder,                nil],
    ['solutions_delete_folder',                       :delete_folder,             nil],
    ['solutions_new_draft',                           :new_article,               :draft],
    ['solutions_new_draft_translation',               :new_article,               :draft],
    ['solutions_published_draft',                     :article,                   :published_draft],
    ['solutions_published_draft_translation',         :article,                   :published_draft],
    ['solutions_delete_draft',                        :delete_article,            :draft],
    ['solutions_delete_draft_translation',            :delete_article,            :draft],

    ['forums_new_forum_category',                     :new_forum_category,        nil],
    ['forums_new_forum',                              :new_forum,                 nil],
    ['forums_new_topic',                              :new_topic,                 nil],
    ['forums_new_post',                               :new_post,                  nil],
    ['forums_published_topic',                        :published_topic,           nil],
    ['forums_published_post',                         :published_post,            nil],
    ['forums_delete_forum_category',                  :delete_forum_category,     nil],
    ['forums_delete_forum',                           :delete_forum,              nil],
    ['forums_delete_topic',                           :delete_topic,              nil],
    ['forums_delete_post',                            :delete_post,               nil],
    ['forums_topic_stamp_1',                          :topic,                     :topic_stamp],
    ['forums_topic_stamp_2',                          :topic,                     :topic_stamp],
    ['forums_topic_stamp_3',                          :topic,                     :topic_stamp],
    ['forums_topic_stamp_4',                          :topic,                     :topic_stamp],
    ['forums_topic_stamp_5',                          :topic,                     :topic_stamp],
    ['forums_topic_stamp_6',                          :topic,                     :topic_stamp],
    ['forums_topic_stamp_7',                          :topic,                     :topic_stamp],
    ['forums_topic_stamp_8',                          :topic,                     :topic_stamp],
    ['forums_topic_stamp_9',                          :topic,                     :topic_stamp],
    ['forums_topic_merge',                            :topic_merge_target,        :topic_merge_target]
  ].freeze

  SUMMARY_MAP_TYPE_BY_NAME = Hash[*SUMMARY_MAP.map { |i| [i[0], i[1]] }.flatten]
  SUMMARY_MAP_ACTION_BY_NAME = Hash[*SUMMARY_MAP.map { |i| [i[0], i[2]] }.flatten]
  SOLUTION_ACTIVITIES = ['Solution::Article', 'Solution::Folder', 'Solution::Category'].freeze

  CONTENT_LESS_TYPES = [:deleted].freeze

  ALLOWED_CONTENT_SUFFIX = %w(name type).freeze

  ACTIVITIES_PREFIX = 'activities.'.freeze

  def to_hash
    {
      id: id,
      object_id: object_id,
      object_type: notable_type,
      title: record.notable.nil? ? record.activity_data[:title] : h(record.notable),
      performer: performer,
      performed_at: Time.at(created_at.to_i).utc,
      actions: user_actions.reject { |action| action.empty? }
    }
  end

  def object_id
    case notable_type
    when 'Helpdesk::Ticket'
      record.notable.display_id
    when *SOLUTION_ACTIVITIES
      record.notable.try(:parent_id)
    else
      notable_id
    end
  end

  def performer
    {
      type: :user,
      performer_type: performing_user
    }
  end

  def performing_user
    user = record.user
    {
      id: user.id,
      name: user.name,
      avatar: avatar_hash(user.avatar),
      is_agent: user.agent?,
      deleted: user.deleted
    }.merge(
      User.current.privilege?(:view_contacts) ? { email: user.email } : {}
    )
  end

  def avatar_hash(avatar)
    return nil if avatar.blank?
    AttachmentDecorator.new(avatar).to_hash.merge(thumb_url: avatar.attachment_url_for_api(true, :thumb))
  end

  def user_actions
    result = {}
    result[:type], result[:content] = activity_info(activity_data)
    [result]
  end

  def activity_info(data)
    content = {}
    @activity_name = activity_name
    action = SUMMARY_MAP_ACTION_BY_NAME[@activity_name]
    type = SUMMARY_MAP_TYPE_BY_NAME[@activity_name]
    content = send(action) if action.present? && respond_to?(action.to_s, true)
    if !CONTENT_LESS_TYPES.include?(type) && data['eval_args'].nil?
      data.each_pair do |k, v|
        key = k.to_s.split('_').last
        content[k] = h v if key.present? && ALLOWED_CONTENT_SUFFIX.include?(key)
      end
    end
    [type, content]
  end

  def activity_name
    action_long = description.split(ACTIVITIES_PREFIX)
    action = action_long[1].chomp('.long').chomp('_none')
    action.gsub!('.', '_')
  end

  # Ticket Methods

  def due_by
    due_by_date = activity_data['eval_args']['due_date_updated'][1]
    { due_by: Time.at(due_by_date.to_i).utc }
  end

  def group
    # activit_data would be null in case of group assigned to none
    activity_data['group_name'].blank? ? { group_name: nil } : {}
  end

  def product
    # activit_data would be null in case of product assigned to none
    activity_data['product_name'].blank? ? { product_name: nil } : {}
  end

  def responder_id
    return { responder_id: nil } if @activity_name.include?('assigned_to_nobody')
    responder = activity_data['eval_args']['responder_path'][1]
    { responder_id: responder['id'], responder_name: responder['name'] }
  end

  def timesheet_new
    { time_spent: [nil, '*'] }
  end

  def timesheet_timer_started
    { timer_running: true }
  end

  def timesheet_timer_stopped
    { timer_running: false }
  end

  def conversation_out_email
    { note_id: activity_data['eval_args']['reply_path'][1]['comment_id'], source: 'email', incoming: false }
  end

  def conversation_out_email_private
    { note_id: activity_data['eval_args']['fwd_path'][1]['comment_id'], source: 'email', incoming: false, private: true, to_emails: activity_data['to_emails'] }
  end

  def conversation_in_email
    { note_id: activity_data['eval_args']['email_response_path'][1]['comment_id'], source: 'email', incoming: true }
  end

  def conversation_note
    { note_id: activity_data['eval_args']['comment_path'][1]['comment_id'] }
  end

  def conversation_twitter
    { note_id: activity_data['eval_args']['twitter_path'][1]['comment_id'], source: 'twitter' }
  end

  def conversation_ecommerce
    { note_id: activity_data['eval_args']['ecommerce_path'][1]['comment_id'], source: 'ecommerce' }
  end

  def ticket_merge_target
    target_ticket = activity_data['eval_args']['merge_ticket_path'][1]
    { target_ticket_id: target_ticket['ticket_id'], title: target_ticket['subject'] }
  end

  def ticket_split_source
    source_ticket = activity_data['eval_args']['split_ticket_path'][1]
    { source_ticket_id: source_ticket['ticket_id'], title: source_ticket['subject'] }
  end

  def ticket_split_target
    target_ticket = activity_data['eval_args']['split_ticket_path'][1]
    { target_ticket_id: target_ticket['ticket_id'], title: target_ticket['subject'] }
  end

  # Solution Methods

  def draft
    { draft: true }
  end

  def published
    { published: true }
  end

  def unpublished
    { published: false }
  end

  def published_draft
    draft.merge(published)
  end

  # Topic Methods

  def topic_stamp
    stamp_type = @activity_name.split('_').last
    stamp_name = Topic::STAMPS_TOKEN_BY_KEY[stamp_type.to_i]
    { stamp_type: stamp_type, stamp_name: stamp_name }
  end

  def topic_merge_target
    { target_topic_id: activity_data['eval_args']['target_topic_path'][1] }
  end
end
