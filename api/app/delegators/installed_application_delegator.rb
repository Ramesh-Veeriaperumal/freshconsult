class InstalledApplicationDelegator < BaseDelegator
  validate :validate_installation, on: :create

  def initialize(item, options = {})
    @app_name = options[:name]
    super(item, options)
  end

  def validate_installation
    app_id = Integrations::Application.select { |app| app.name == @app_name }.map(&:id).first
    errors[:name] << :already_installed if Account.current.installed_applications.map { |app| app.application_id == app_id }.include?(true)
  end
end
