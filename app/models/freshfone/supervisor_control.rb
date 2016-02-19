
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
    [ :whispering,  'whispering', 3 ]
  ]
    CALL_TYPE_HASH = Hash[*CALL_TYPE.map { |i| [i[0], i[2]] }.flatten]


  CALL_STATUS = [
    [ :default, 'default', 0 ],
    [ :success, 'success', 1 ],
    [ :failed, 'failed', 2]
  ]

  	CALL_STATUS_HASH = Hash[*CALL_STATUS.map { |i| [i[0], i[2]] }.flatten]

  scope :active, :conditions => ["supervisor_control_status = ?",
              CALL_STATUS_HASH[:default]], :limit => 1

  scope :recent_completed_call, :conditions => ["supervisor_control_status = ? and cost IS NULL",
              CALL_STATUS_HASH[:success]], :limit => 1, :order => "created_at DESC"

  def completed?
    supervisor_control_status == CALL_STATUS_HASH[:success]
  end

  def update_details(params)
    self.duration = params[:CallDuration]
    self.supervisor_control_status = params[:status]
    self.save
  end

  def register_supervisor_in_redis
    register_supervisor_leg account_id, supervisor_id, sid, call_id
  end

  def remove_supervisor_in_redis
    remove_supervisor_leg account_id, supervisor_id, sid
  end

end
