class CactusAuditEventsController < ApplicationController
  before_action :ensure_admin

  def index
    @event_action = params[:event_action].presence
    @actions = Current.account.audit_events.distinct.order(:action).pluck(:action)

    audit_events = Current.account.audit_events.includes(:user).latest_first
    audit_events = audit_events.where(action: @event_action) if @event_action.in?(@actions)

    set_page_and_extract_portion_from audit_events
    @audit_events = @page.records
  end
end
