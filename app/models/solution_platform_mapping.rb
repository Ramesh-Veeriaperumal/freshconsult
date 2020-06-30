class SolutionPlatformMapping < ActiveRecord::Base
  self.primary_key = :id

  belongs_to_account
  belongs_to :mappable, polymorphic: true

  attr_accessible :web, :ios, :android

  PLATFORMS = ['web', 'ios', 'android'].freeze
  PLATFORM_DEFAULT_VALUES = PLATFORMS.map { |platform| [platform, false] }.to_h

  def modified_new_platform_values(new_values)
    attributes.slice(*PLATFORMS).merge(new_values.with_indifferent_access)
  end

  def to_hash
    attributes.slice(*PLATFORMS)
  end

  def self.default_platform_values_hash
    PLATFORM_DEFAULT_VALUES
  end

  def self.any_platform_enabled?(platform_hash)
    platform_hash.values.any?
  end
end
