# -*- encoding : utf-8 -*-
require 'logger'
require 'net/https'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/hash/conversions'

# A library to assist in using the eBay Trading API.
module Ebayr
  autoload :Record,   File.expand_path('../ebayr/record', __FILE__)
  autoload :Request,  File.expand_path('../ebayr/request',  __FILE__)
  autoload :Response, File.expand_path('../ebayr/response', __FILE__)
  autoload :User,     File.expand_path('../ebayr/user',     __FILE__)


  mattr_accessor :dev_id
  mattr_accessor :app_id
  mattr_accessor :cert_id
  mattr_accessor :ru_name
  mattr_accessor :auth_token

  # Determines whether to use the eBay sandbox or the real site.
  mattr_accessor :sandbox
  self.sandbox = true

  def sandbox?
    !!sandbox
  end


  # The eBay Site to use for calls. The full list of available sites can be
  # retrieved with <code>GeteBayDetails(:DetailName => "SiteDetails")</code>
  mattr_accessor :site_id
  self.site_id = 0

  # eBay Trading API version to use. For more details, see
  # http://developer.ebay.com/devzone/xml/docs/HowTo/eBayWS/eBaySchemaVersioning.html
  mattr_accessor :compatability_level
  self.compatability_level = 927

  def uri_prefix(service = "api")
    "https://#{service}#{sandbox ? ".sandbox" : ""}.ebay.com/ws"
  end

  def uri(*args)
    URI::parse("#{uri_prefix(*args)}/api.dll")
  end

  def call(command,ebay_acc_id, arguments = {})
    Request.new(command,ebay_acc_id, arguments).send
  end

  def self.included(mod)
    mod.extend(self)
  end

  extend self
end


