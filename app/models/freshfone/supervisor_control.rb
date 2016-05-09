
class Freshfone::SupervisorControl < ActiveRecord::Base
  include Freshfone::CallsRedisMethods
	self.primary_key = :id
	self.table_name =  :freshfone_supervisor_controls

  after_commit :register_supervisor_in_redis, on: :create
  after_commit :remove_supervisor_in_redis, on: :update
	belongs_to_account

	belongs_to :call, :class_name => 'Freshfone::Call', :foreign_key => 'call_id'
	belongs_to :supervisor, :class_name => '::User', :foreign_key => 'supervisor_id'	

	CALL_TYPE = [
    [ :monitoring,  'monitoring', 1 ],
    [ :barging,  'barging', 2 ],
    [ :whispering,  'whispering', 3 ],
    [ :agent_conference, 'agent_conference', 4 ]
  ]
  CALL_TYPE_HASH = Hash[*CALL_TYPE.map { |i| [i[0], i[2]] }.flatten]


  CALL_STATUS = [
    [ :default, 'default', 0 ],
    [ :success, 'success', 1 ],
    [ :completed, 'completed', 1 ],
    [ :failed, 'failed', 2 ],
    [ :ringing, 'ringing', 3 ],
    [ :'in-progress', 'in-progress', 4 ],
    [ :canceled, 'canceled', 5 ],
    [ :busy, 'busy', 6 ],
    [ :'no-answer', 'no-answer', 7 ]    
  ]

  CALL_STATUS_HASH = Hash[*CALL_STATUS.map { |i| [i[0], i[2]] }.flatten]

  scope :active, :conditions => ["supervisor_control_status = ? and supervisor_control_type = ?",
              CALL_STATUS_HASH[:default], CALL_TYPE_HASH[:monitoring]], :limit => 1

  scope :recent_completed_call, :conditions => ["supervisor_control_status = ? and cost IS NULL",
              CALL_STATUS_HASH[:success]], :limit => 1, :order => "created_at DESC"

  scope :agent_conference_calls, lambda { |status|
    where(supervisor_control_status: status,
          supervisor_control_type: CALL_TYPE_HASH[:agent_conference])
  }

  scope :supervisor_progress_call, lambda { |user_id|
    where(
      supervisor_control_status:
        [CALL_STATUS_HASH[:default], CALL_STATUS_HASH[:'in-progress']],
      supervisor_id: user_id)
  }

  CALL_TYPE_HASH.each_pair do |k, v|
    define_method("#{k}?") do
      supervisor_control_type == v
    end
  end

  def completed?
    supervisor_control_status == CALL_STATUS_HASH[:success]
  end

  def update_details(params)
    self.duration = params[:CallDuration] if params[:CallDuration].present?
    self.supervisor_control_status = params[:status] if params[:status].present?
    self.sid = params[:sid] if params[:sid].present?
    save
  end

  def update_status(status)
    self.supervisor_control_status = status
    save
  end

  def register_supervisor_in_redis
    register_supervisor_leg account_id, supervisor_id, sid, call_id
  end

  def remove_supervisor_in_redis
    remove_supervisor_leg account_id, supervisor_id, sid
  end

end
