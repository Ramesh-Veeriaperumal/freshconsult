module Integrations::Office365
  class RsaPemFromModExp

    def get_pem modulus,exponent
      modulus += '=' * (4 - modulus.length.modulo(4))
      modulus.tr!('-_','+/')
      modulus_hex = modulus.unpack("m0").first.unpack("H*").first
      exponent_hex = exponent.unpack("m0").first.unpack("H*").first 
      n = OpenSSL::BN.new(modulus_hex, 16)
      e = OpenSSL::BN.new(exponent_hex,16)
      ary = [OpenSSL::ASN1::Integer.new(n), OpenSSL::ASN1::Integer.new(e)]
      pub_key = OpenSSL::ASN1::Sequence.new(ary)
      base64 = Base64.encode64(pub_key.to_der)

      pem = "-----BEGIN RSA PUBLIC KEY-----\n#{base64}-----END RSA PUBLIC KEY-----"
      return pem
    end

  end
end
