class EmailNotificationValidation < ApiValidation
  attr_accessor :notification_type, :requester_notification, :requester_subject_template, :requester_template, 
  :agent_notification, :agent_subject_template, :agent_template

  CHECK_PARAMS_SET_FIELDS = %w(requester_template requester_subject_template agent_template agent_subject_template).freeze

  validates :requester_notification, :agent_notification, data_type: { rules: 'Boolean' }

  validates :requester_template, :requester_subject_template, custom_absence: {
    message: :inaccessible_field,
    code: :inaccessible_field,
  }, unless: :requester_visible_template?
  validates :agent_template, :agent_subject_template, custom_absence: {
    message: :inaccessible_field,
    code: :inaccessible_field,
  }, unless: :agent_visible_template?

  validates :requester_template, :requester_subject_template, data_type: { rules: String }, if: :requester_visible_template?
  validates :agent_template, :agent_subject_template, data_type: { rules: String }, if: :agent_visible_template?

  validates :requester_template, :requester_subject_template, presence: true, if: :requester_visible_template?
  validates :agent_template, :agent_subject_template, presence: true, if: :agent_visible_template?

  private

    def requester_visible_template?
      @requester_visible_template ||= EmailNotification.requester_visible_template?(notification_type)
    end

    def agent_visible_template?
      @agent_visible_template ||= EmailNotification.agent_visible_template?(notification_type)
    end
end
