class Admin::RequesterWidgetController < ApplicationController
  
  include Helpdesk::RequesterWidgetHelper
  helper Helpdesk::RequesterWidgetHelper
  include Cache::Memcache::ContactField
  include Cache::Memcache::CompanyField
  include Cache::Memcache::Account
  
  def get_widget
    render :partial => "get_widget"
  end

  def update_widget
    widget_fields = JSON.parse(ActiveSupport::JSON.decode(params["requester_widget_config"]))
    deleted_fields = JSON.parse(ActiveSupport::JSON.decode(params["deleted_widget_config"]))

    customer_fields = { "contact" => current_account.contact_form.contact_fields,
                        "company" => current_account.company_form.company_fields }
    [widget_fields, deleted_fields].each do |list|
      list.each do |widget_field|
        if widget_field.key?("type") && ["contact", "company"].include?(widget_field["type"])
          field = customer_fields[widget_field["type"]].find { |f|
            f.id == widget_field["id"]
          }
          next if field.blank?
          field.field_options ||= {}
          if widget_field.key?("position")
            if field.field_options["widget_position"] != widget_field["position"]
              field.field_options["widget_position"] = widget_field["position"]
              field.save
            end
          else
            field.save if field.field_options.delete("widget_position")
          end
        end
      end
    end
    clear_company_fields_cache
    clear_contact_fields_cache
    clear_requester_widget_fields_from_cache
    flash[:notice] = t(:'requester_fields_updated')
    redirect_to :back
  end
end
