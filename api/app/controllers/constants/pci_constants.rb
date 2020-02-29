module PciConstants
  ISSUER = 'freshdesk'.freeze
  OBJECT_TYPE = 'ticket'.freeze
  EXPIRY_DURATION = 2.minutes.freeze
  ACTION = {
    none: 0,
    read: 1,
    write: 2
  }.freeze
  PUBLIC_KEY = File.read('config/cert/jwe_encryption_key.pem')
end
