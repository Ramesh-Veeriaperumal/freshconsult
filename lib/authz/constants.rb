module Authz::Constants
  HOST_URL = AuthzConfig[:host]
  PRODUCT = 'freshdesk'.freeze
  PRODUCT_ID = AuthzConfig[:product_id]
  TIMEOUT = AuthzConfig[:timeout]
end
