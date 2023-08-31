# frozen_string_literal: true

require "jwt"

class JsonWebToken
  class << self
    def decode(token)
      payload = JWT.decode(token, public_key, true, {algorithm: "RS256"}).first
      HashWithIndifferentAccess.new(payload)
    rescue
      nil
    end

    private
    
    def public_key
      @_public_key ||= begin
        public_key_content = File.read(Rails.root.join("config", "keys", "public_key.pem"))
        OpenSSL::PKey::RSA.new(public_key_content)
      end
    end
  end
end
