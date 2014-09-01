module Integrations::Util

	def pivotal_tracker_split_resource(pivotal_integrated_resource,installed_app)
    remote_integratable_id = local_integratable_id = application_ids = resource_id= ""
    application_ids = installed_app["configs"][:inputs]["webhooks_applicationid"].join(",") if installed_app["configs"][:inputs].include? "webhooks_applicationid"
    pivotal_integrated_resource.each do |resource|
      remote_integratable_id += resource[:remote_integratable_id].to_s + ","
      local_integratable_id +=  resource[:local_integratable_id].to_s + ","
      resource_id += resource[:id].to_s + "," 
    end
    pivotal_resource = {"remote_integratable_id" => remote_integratable_id.chomp(","), "local_integratable_id" => local_integratable_id.chomp(","),
      "webhooks_application_ids" => application_ids,"get_updates" => installed_app["configs"][:inputs]["pivotal_update"],
      "resource_id" => resource_id.chomp(",") }
  end
end