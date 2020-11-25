module Integrations
  module AppMarketPlaceExtension
    extend ActiveSupport::Concern
    include MarketplaceAppHelper
    include Marketplace::GalleryConstants

    included do

      include ::Marketplace::HelperMethods

      after_create :marketplace_app_create, :unless => :is_freshplug?, :if => :marketplace_enabled?
      after_update :marketplace_app_update, :unless => :is_freshplug?, :if => :marketplace_enabled?
      after_destroy :marketplace_app_delete, :unless => :is_freshplug?, :if => :marketplace_enabled?

      after_commit :marketplace_updates, :unless => [:is_freshplug?, :marketplace_enabled?]
    end


    # Instance Methods
    def marketplace_enabled?
      Account.current.features?(:marketplace)
    end

    private

    def marketplace_app_create
      begin
        raise "Api Failed" unless app_updates('install', application.name, configs)
      rescue => e
        self.errors[:base] << "Marketplace Api Failed"
        raise ActiveRecord::Rollback
      end
    end

    def marketplace_app_update
      begin
        raise "Api Failed" unless app_updates('update', application.name, configs)
      rescue => e
        self.errors[:base] << "Marketplace Api Failed"
        raise ActiveRecord::Rollback
      end
    end

    def marketplace_app_delete
      return if skip_makrketplace_syncup

      begin
        raise "Api Failed" unless app_updates('uninstall', application.name)
      rescue => e
        self.errors[:base] << "Marketplace Api Failed"
        raise ActiveRecord::Rollback
      end
    end

    def app_updates(method, app_name, configs = nil)
      return true if Rails.env.development? || Rails.env.test?

      mkt_obj = ::Marketplace::MarketPlaceObject.new
      ni_latest_result = mkt_obj.safe_send(:ni_latest_details, app_name)
      return false if mkt_obj.safe_send(:error_status?, ni_latest_result)
      params = ni_latest_result.body.symbolize_keys
      params.merge!({:type => ::Marketplace::Constants::EXTENSION_TYPE[:ni]})
      
      extn_details = mkt_obj.safe_send(:extension_details, params[:extension_id], params[:type])
      return false if mkt_obj.safe_send(:error_status?, extn_details)
      @extension = extn_details.body

      params.merge!(paid_app_params) if ['install', 'uninstall'].include?(method)
      params.merge!(contact_details) if should_add_contact_details?(method, app_name)
      params.merge!({
        :configs => configs,
        :enabled => ::Marketplace::Constants::EXTENSION_STATUS[:enabled]
      }) if ['install', 'update'].include?(method)

      ext_result = mkt_obj.safe_send("#{method}_extension", params)

      return false if mkt_obj.safe_send(:error_status?, ext_result)

      cache_paid_app_details(app_name, ext_result) if method == 'install' && should_verify_billing?
      true
    end

    def marketplace_updates
      method = transaction_include_action?(:create) ? :install : ( transaction_include_action?(:update) ? :update : :uninstall )
      params = { :method => method, :name => application.name, :configs => configs }
      Admin::MarketplaceAppsWorker.perform_async(params)
    end

    def cache_paid_app_details(app_name, ext_result)
      installed_extension_id = ext_result.body.try(:[], 'installed_extension_id')
      set_or_add_marketplace_ni_extension_details(Account.current.id, app_name, installed_extension_id)
    end

    def contact_details
      {
        contact_details: { emails: User.current.emails }
      }
    end

    def should_verify_billing?
      Account.current.marketplace_gallery_enabled? && NATIVE_PAID_APPS.include?(application.name)
    end

    def should_add_contact_details?(method, app_name)
      Account.current.marketplace_gallery_enabled? && method == 'install' && NATIVE_PAID_APPS.include?(app_name)
    end
  end
end
