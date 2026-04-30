module RequestForgeryProtection
  extend ActiveSupport::Concern

  included do
    protect_from_forgery using: :header_only, with: :exception
  end

  private
    def verified_request?
      super || allowed_request_without_fetch_metadata?
    end

    def allowed_request_without_fetch_metadata?
      sec_fetch_site_value.nil? && (request.format.json? || insecure_http_request?)
    end

    def insecure_http_request?
      !request.ssl? && !Rails.configuration.force_ssl
    end

    def sec_fetch_site_value
      request.headers["Sec-Fetch-Site"]
    end
end
