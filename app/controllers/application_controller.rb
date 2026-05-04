class ApplicationController < ActionController::Base
  include Authentication
  include Authorization
  include CactusAuthorization
  include BlockSearchEngineIndexing
  include CurrentRequest, CurrentTimezone, SetPlatform
  include RequestForgeryProtection
  include TurboFlash, ViewTransitions
  include RoutingHeaders

  etag { "v1" }
  stale_when_importmap_changes
  allow_browser versions: :modern, unless: :legacy_user_agent_allowlisted?

  private
    def legacy_user_agent_allowlisted?
      user_agent = request.user_agent.to_s.downcase
      user_agent.include?("baidubrowser") ||
        user_agent.include?("googleimageproxy") ||
        user_agent.include?("facebookexternalhit") ||
        user_agent.include?("facebot") ||
        user_agent.include?("twitterbot")
    end
end
