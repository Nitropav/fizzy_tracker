class LegacyImports::AsanaImportsController < ApplicationController
  before_action :ensure_can_import_cactus_issues

  def show
    @asana_import = Current.account.legacy_asana_imports
      .includes(:board, :creator)
      .find(params[:id])
  end
end
