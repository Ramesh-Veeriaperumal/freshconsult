class IntegratedResourceDecorator < ApiDecorator
  delegate :id, :installed_application_id, :remote_integratable_id, :local_integratable_id, :remote_integratable_type, to: :record

  def to_hash
    {
      id: id,
      installed_application_id: installed_application_id,
      remote_integratable_id: remote_integratable_id,
      remote_integratable_type: remote_integratable_type,
      local_integratable_id: local_integratable_id
    }
  end
end
