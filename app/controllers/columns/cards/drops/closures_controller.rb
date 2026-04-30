class Columns::Cards::Drops::ClosuresController < ApplicationController
  include CardScoped

  def create
    @card.close
  rescue Card::Closeable::GateTwoIncomplete => error
    render turbo_stream: turbo_stream_flash(alert: error.message), status: :unprocessable_entity
  end
end
