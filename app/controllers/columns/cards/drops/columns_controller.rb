class Columns::Cards::Drops::ColumnsController < ApplicationController
  include CardScoped

  def create
    @column = @card.board.columns.find(params[:column_id])
    @card.triage_into(@column)
  rescue Card::Triageable::GateOneIncomplete => error
    render turbo_stream: turbo_stream_flash(alert: error.message), status: :unprocessable_entity
  end
end
