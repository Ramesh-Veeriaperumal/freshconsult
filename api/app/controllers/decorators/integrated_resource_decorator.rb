class IntegratedResourceDecorator < ApiDecorator
delegate :id, :installed_application_id, :remote_integratable_id, :local_integratable_type, :local_integratable_id, to: :record

def to_hash
	
  res_hash = {
  	id: record.id,
  	installed_application_id: record.installed_application_id,
  	remote_integratable_id: record.remote_integratable_id,
  	local_integratable_type: record.local_integratable_type,
    local_integratable_id: record.local_integratable_id
  }
  res_hash
end
end