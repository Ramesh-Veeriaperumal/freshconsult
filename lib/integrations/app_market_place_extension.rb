module Integrations
  module AppMarketPlaceExtension
    extend ActiveSupport::Concern

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
      begin
        raise "Api Failed" unless app_updates('uninstall', application.name)
      rescue => e
        self.errors[:base] << "Marketplace Api Failed"
        raise ActiveRecord::Rollback
      end
    end

    def app_updates(method, app_name, configs = nil)
      return true if Rails.env.development?
      mkt_obj = ::Marketplace::MarketPlaceObject.new
      ni_latest_result = mkt_obj.send(:ni_latest_details, app_name)
      return false if mkt_obj.send(:error_status?, ni_latest_result)
      params = ni_latest_result.body.symbolize_keys

      extn_details = mkt_obj.send(:extension_details, params[:extension_id])
      return false if mkt_obj.send(:error_status?, extn_details)
      @extension = extn_details.body

      params.merge!(paid_app_params) if ['install', 'uninstall'].include?(method)

      params.merge!({
        :configs => configs,
        :type => ::Marketplace::Constants::EXTENSION_TYPE[:ni],
        :enabled => ::Marketplace::Constants::EXTENSION_STATUS[:enabled]
      }) if ['install', 'update'].include?(method)

      ext_result = mkt_obj.send("#{method}_extension", params)

      return false if mkt_obj.send(:error_status?, ext_result)
      true
    end

    def marketplace_updates
      method = transaction_include_action?(:create) ? :install : ( transaction_include_action?(:update) ? :update : :uninstall )
      params = { :method => method, :name => application.name, :configs => configs }
      Admin::MarketplaceAppsWorker.perform_async(params)
    end

  end
end