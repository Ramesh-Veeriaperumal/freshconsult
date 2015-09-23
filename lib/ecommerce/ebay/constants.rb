module Ecommerce::Ebay::Constants

  EBAY_RATE_LIMIT_ERROR       =  ["518", "18000", "218050", "21919144", "21919165"]
  EBAY_INVALID_ARGS_ERROR     =  "37"
  EBAY_AUTHENTICATION_FAILURE =  "931"
  EBAY_ERROR_LANGUAGE         =  "en_IN"
  EBAY_SUCCESS_MSG            =  "Success"
  EBAY_ERROR_MSG              =  "Failure"
  EBAY_SCHEDULE_AFTER         =  4.hours
  EBAY_SUBJECT_REPLY          =  'Re: '
  EBAY_TAG                    =  "eBay"
  EBAY_MAXIMUM_RETRY          =  5
  EBAY_REPLY_MSG_LENGTH       =  2000
  MAX_ECOMMERCE_ACCOUNTS      =  5
  EBAY_DEVICE_TYPE            = "Platform"
  EBAY_ENABLE_TYPE            = { "enable" => "Enable", "disable" => "Disable" }
  EBAY_EVENT_TYPES            = { "my_messages_m2m" => "MyMessagesM2MMessage", "fixed_price" => "FixedPriceTransaction" }
  EBAY_SENT_FOLDER_ID         = 1
  EBAY_DETAIL_LEVEL           = {"headers" => "ReturnHeaders", "messages" => "ReturnMessages","item_description" => "ItemReturnDescription"}
  EBAY_SESSION_DATA           = ["ebay_session_id", "ebay_site_id", "ebay_account_name", "product_id", "group_id"]
  EBAY_PREFIX                 = "fbay"
  EBAY_DEFAULT_SYNC_PERIOD    = 2.days
  EBAY_MAX_ENTRY              = 100 
  EBAY_MAX_PAGE               = *(1..10) 
  EBAY_API_LOW_WARNING_LIMIT  = 1000000
  EBAY_API_HIGH_WARNING_LIMIT = 1300000
  EBAY_AUTHORIZE_URL          = "#{EbayConfig::AUTHORIZE_URL}&RUName=#{Ebayr.ru_name}&SessID=%{session_id}&ruparams=%{ruparams}"

  EBAY_SITE_CODE = [
    [ "eBay Australia", 15 ],
    [ "eBay Austria", 16 ], 
    [ "eBay Belgium (Dutch)", 123 ],
    [ "eBay Belgium (French)", 23 ],
    [ "eBay Canada (English)", 2 ],
    [ "eBay Canada (French)", 210 ],
    [ "eBay France", 71 ],
    [ "eBay Germany", 77 ], 
    [ "eBay Hong Kong", 201 ],
    [ "eBay India", 203  ],
    [ "eBay Ireland", 205 ],   
    [ "eBay Italy", 101  ],
    [ "eBay Malaysia", 207],  
    [ "eBay Motors", 100],
    [ "eBay Netherlands", 146 ],
    [ "eBay Philippines", 211 ],
    [ "eBay Poland", 212 ],
    [ "eBay Spain", 186 ],
    [ "eBay Singapore ", 216 ] ,
    [ "eBay Switzerland", 193 ], 
    [ "eBay UK", 3],
    [ "eBay United States", 0 ]
  ]

  EBAY_SITE_CODE_TYPES = Hash[*EBAY_SITE_CODE.map { |i| [i[0], i[1]] }.flatten]
  EBAY_SITE_BY_CODE = Hash[*EBAY_SITE_CODE.map { |i| [i[1], i[0]] }.flatten]

end