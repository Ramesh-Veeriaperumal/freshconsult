module Freshfone::Response
  STATUS_CODE = { ok: 200,
                	invalid: -1,    
                  low_credit: 1001,
                  dial_restricted_country: 1002,
                  trial_expired: 1003,
                  trial_outgoing_exhausted: 1004,
                  invalid_phone: 1005 }  

  def asserted_status(sym_code = nil)
    sym_code = :invalid if STATUS_CODE[sym_code].blank?
    { :status => sym_code.to_s, :code => STATUS_CODE[sym_code] }
  end
end
