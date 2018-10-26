module Redis::Keys::Portal

  PORTAL_PREVIEW                  = "PORTAL_PREVIEW:%{account_id}:%{user_id}:%{template_id}:%{label}".freeze
  IS_PREVIEW                      = "IS_PREVIEW:%{account_id}:%{user_id}:%{portal_id}".freeze
  PREVIEW_URL                     = "PREVIEW_URL:%{account_id}:%{user_id}:%{portal_id}".freeze
  PORTAL_CACHE_ENABLED            = "PORTAL_CACHE_ENABLED".freeze
  PORTAL_CACHE_VERSION            = "PORTAL_CACHE_VERSION:%{account_id}".freeze
  SOLUTIONS_PORTAL_CACHE_VERSION  = "SOLUTIONS_PORTAL_CACHE_VERSION:%{account_id}".freeze
  SITEMAP_OUTDATED                = "SITEMAP_OUTDATED:%{account_id}".freeze
end