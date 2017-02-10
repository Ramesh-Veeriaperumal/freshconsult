class IntegratedUserDecorator < ApiDecorator
delegate :id, :installed_application_id, :user_id, :auth_info, :remote_user_id, to: :record

def to_hash
	
  res_hash = {
  	id: record.id,
  	installed_application_id: record.installed_application_id,
  	user_id: record.user_id,
  	auth_info: record.auth_info,
    remote_user_id: record.remote_user_id
  }
  res_hash
end
end