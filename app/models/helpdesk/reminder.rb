class Helpdesk::Reminder < ActiveRecord::Base
  self.table_name =  'helpdesk_reminders'
  self.primary_key = :id

  belongs_to_account
  belongs_to :user, class_name: 'User'
  belongs_to :ticket, class_name: 'Helpdesk::Ticket'
  belongs_to :contact, class_name: 'User', foreign_key: 'contact_id', 
    inverse_of: :contact_reminders
  belongs_to :company, class_name: 'Company', foreign_key: 'company_id', 
    inverse_of: :reminders

  scope :visible, ->{
    where(deleted: false).order('updated_at ASC, created_at ASC')
  }

  scope :logged, ->(time){
    where(["deleted = ? AND updated_at > ?", true, time]).
    order('deleted ASC, updated_at DESC, created_at DESC')
  }

  belongs_to :contact, class_name: 'User', foreign_key: 'contact_id',
    inverse_of: :contact_reminders

  scope :with_resources, lambda { |resources|
                          self.preload(*resources).order("id DESC") if resources.present?
                        }
  scope :scheduled, ->{ where('reminder_at is not null') }
  attr_accessible :body, :deleted, :user, :reminder_at
  
  validates_numericality_of :user_id
  validates_presence_of :body
  validates_length_of :body, :in => 1..TodoConstants::MAX_LENGTH_OF_TODO_CONTENT

  before_create :set_account_id
  before_update :create_model_changes
  after_commit  ->(obj) { obj.trigger_todos_reminder_scheduler }, on: :create, if: :reminder_modified?
  after_commit  ->(obj) { obj.trigger_todos_reminder_scheduler }, on: :update, if: :reminder_modified?
  after_commit ->(obj) { obj.cancel_todos_reminder_scheduler }, on: :update, if: :todo_completed?
  after_commit ->(obj) { obj.trigger_todos_reminder_scheduler }, on: :update, if: :todo_not_completed?
  after_commit ->(obj) { obj.cancel_todos_reminder_scheduler }, on: :destroy, if: :job_id

  def rememberable_type
    @type ||= begin
      rememberable_map = TodoConstants::REMEMBERABLE_FIELD_MAP.select do |field_map|
        read_attribute(field_map[1]).present?
      end.first
      rememberable_map && rememberable_map[0]  
    end
  end

  def create_model_changes
    @model_changes = self.changes.clone.to_hash
    @model_changes.symbolize_keys!
  end

  def rememberable_attribute(attribute, rememberable=nil, association_attr=nil)
    if rememberable.present?
      attribute && rememberable.send(attribute)
    elsif association_attr.present? && attribute && send("#{association_attr}_id").present?
      send(association_attr).try(attribute)
    end
  end

  def trigger_todos_reminder_scheduler
    payload = {
      job_id: job_id,
      message_type: TodoConstants::MESSAGE_TYPE,
      group: ::SchedulerClientKeys['todo_group_name'],
      scheduled_time: reminder_at,
      data: {
        account_id: Account.current.id,
        reminder_id: id,
        enqueued_at: Time.now.to_i,
        scheduler_type: TodoConstants::SCHEDULER_TYPE
      },
      sqs: {
        url: AwsWrapper::SqsV2.queue_url(SQS[:fd_scheduler_reminder_todo_queue])
      }
    }
    ::Scheduler::PostMessage.perform_async(payload: payload) if Account.current.todos_reminder_scheduler_enabled?
  end

  def cancel_todos_reminder_scheduler
    ::Scheduler::CancelMessage.perform_async(job_ids: Array(job_id), group_name: group_name) if Account.current.todos_reminder_scheduler_enabled?
  end

  private

    # since reminder.user is api_current_user setting Account.current.id to avoid user query
    def set_account_id
      self.account_id = Account.current.id || user.account_id
    end

    def reminder_modified?
      previous_changes.key?(:reminder_at) && job_id
    end

    def todo_completed?
      job_id && @model_changes.key?(:deleted) && @model_changes[:deleted][1]
    end

    def todo_not_completed?
      job_id && @model_changes.key?(:deleted) && @model_changes[:deleted][0]
    end

    def job_id
      if reminder_at && (reminder_at > Time.now.iso8601)
        [Account.current.id, 'reminder', id].join('_')
      end
    end

    def group_name
      ::SchedulerClientKeys['todo_group_name']
    end
end
