class Admin::CannedResponses::Response < ActiveRecord::Base
  include RepresentationHelper
  DATETIME_FIELDS = [:created_at, :updated_at].freeze
  ACTIONS = [:create, :update, :destroy].freeze
  acts_as_api

  api_accessible :central_publish do |v|
    v.add :id
    v.add :title
    v.add :content
    v.add :content_html
    v.add :folder_id
    v.add :deleted
    v.add proc { |x| { user_id: x.users.map(&:id), visibility: x.helpdesk_accessible.access_type, group_ids: x.groups.map(&:id) } }, as: :visibility
    v.add proc { |x| x.shared_attachments.map(&:id) }, as: :attachment_ids
    DATETIME_FIELDS.each do |key|
      v.add proc { |x| x.utc_format(x.send(key)) }, as: key
    end
  end

  api_accessible :central_publish_associations do |t|
    t.add :shared_attachments, template: :central_publish
    t.add :folder, template: :central_publish
  end

  def central_payload_type
    action = ACTIONS.find { |act| transaction_include_action? act }
    return 'canned_response_destroy' if action_destroy.present?

    "canned_response_#{action}"
  end

  def event_info(_action)
    { ip_address: Thread.current[:current_ip] }
  end

  def model_changes_for_central
    changes = @model_changes
    changes[:visibility] = {} if @group_access_changes.present? && !changes.key?(:visibility)
    changes[:visibility][:groups] = build_add_remove_changes(groups, @group_access_changes) if @group_access_changes.present?
    changes[:attachments] = build_add_remove_changes(attachments_sharable, @attachment_changes) if @attachment_changes.present?
    changes[:attachments] = {} if @attachment_changes.blank? && attachment_removed.present?
    changes[:attachments][:removed] = attachment_removed if attachment_removed.present?
    changes
  end

  def build_add_remove_changes(data, m_changes)
    ids = data.pluck :id
    changes_hash = { added: [], removed: [] }
    m_changes.uniq.each do |ag|
      temp ||= ag.is_a?(Integer) ? ag : ag[:id]
      ids.include?(temp) ? changes_hash[:added].push(ag) : changes_hash[:removed].push(ag)
    end
    changes_hash
  end

  def relationship_with_account
    'canned_responses'
  end
end
