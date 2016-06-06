module Integrations::CloudElements::CloudElementsUtil

  def delete_element_instance installed_app, payload, metadata
    service_obj = IntegrationServices::Services::CloudElementsService.new( installed_app, payload, metadata)
    service_obj.receive(:delete_element_instance)
  end

  def delete_formula_instance installed_app, payload, metadata
    service_obj = IntegrationServices::Services::CloudElementsService.new( installed_app, payload, metadata)
    service_obj.receive(:delete_formula_instance)
  end

end