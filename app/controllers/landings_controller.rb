class LandingsController < ApplicationController
  def show
    flash.keep(:welcome_letter)

    redirect_to root_path
  end
end
