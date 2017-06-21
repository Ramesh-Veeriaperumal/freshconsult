module IntegratedResourcesTestHelper
  def integrated_resource_pattern(app, _output = {})
    {
      id: app.id,
      installed_application_id: app.installed_application_id,
      remote_integratable_id: app.remote_integratable_id,
      remote_integratable_type: app.remote_integratable_type,
      local_integratable_id: app.local_integratable_id
    }
  end
end
