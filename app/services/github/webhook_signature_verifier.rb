module Github
  class WebhookSignatureVerifier
    SIGNATURE_HEADER = "X-Hub-Signature-256"

    def initialize(payload:, signature:, secret:)
      @payload = payload.to_s
      @signature = signature.to_s
      @secret = secret.to_s
    end

    def valid?
      return false if secret.blank? || signature.blank?

      ActiveSupport::SecurityUtils.secure_compare(signature, expected_signature)
    rescue ArgumentError
      false
    end

    private
      attr_reader :payload, :signature, :secret

      def expected_signature
        "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', secret, payload)}"
      end
  end
end
