class Integrations::NativeWidget < StaticModel::Base
  set_data_file Rails.root.join("config","widget_data.yml")
  #   belongs_to :application, :class_name =>'Integrations::Application', :foreign_key => "application_id"
  include Integrations::WidgetCore
end
