class Integrations::InstalledApplication < ActiveRecord::Base
  
  include RepresentationHelper

  acts_as_api

  DATETIME_FIELDS = [:created_at, :updated_at].freeze


  api_accessible :central_publish do |t|
    t.add :id
    t.add :application_id
    t.add :account_id
    t.add :encrypt_configs, as: :encrypted_configs
    t.add proc {|x| x.encryption_key_name('installed_application')}, as: :encryption_key_name
    DATETIME_FIELDS.each do |key|
      t.add proc { |x| x.utc_format(x.safe_send(key)) }, as: key
    end
  end


  api_accessible :central_publish_associations do |t|
    t.add :application, template: :central_publish
  end

  def model_changes_for_central 
    if(@model_changes.include?("configs"))
      @model_changes[:configs][0] = encrypt_for_central(@model_changes[:configs][0].to_json.to_s, 'installed_application')
      @model_changes[:configs][1] = encrypt_for_central(@model_changes[:configs][1].to_json.to_s, 'installed_application')
    end
    DATETIME_FIELDS.each do |value|
      if @model_changes.include?(value)
        @model_changes[value][0] = utc_format(@model_changes[value][0])
        @model_changes[value][1] = utc_format(@model_changes[value][1])
      end
    end
    @model_changes
  end

  def encrypt_configs
    if self.configs.present?
      encrypt_for_central(self.configs.to_json.to_s, 'installed_application')
    end
  end

end