class SolutionPlatformMapping < ActiveRecord::Base
  self.primary_key = :id

  belongs_to_account
  belongs_to :mappable, polymorphic: true

  attr_accessible :web, :ios, :android

  PLATFORMS = ['web', 'ios', 'android'].freeze
  PLATFORM_DEFAULT_VALUES = PLATFORMS.map { |platform| [platform, false] }.to_h

  # new_values - new platform values
  # this method returns the modified platform values, after updating the existing platform values with new platform values
  # in update article and folder API, platform row will be updated only if atleast one platform is true or else the row will be deleted
  # this modified value is used in update API to decide whether to update the platform row or delete the row
  def modified_new_platform_values(new_values)
    attributes.slice(*PLATFORMS).merge(new_values.with_indifferent_access)
  end

  def to_hash
    attributes.slice(*PLATFORMS)
  end

  def self.any_platform_enabled?(platform_hash)
    platform_hash.values.any?
  end

  def self.default_platform_values_hash
    PLATFORM_DEFAULT_VALUES
  end
end
