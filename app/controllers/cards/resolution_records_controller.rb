class Cards::ResolutionRecordsController < ApplicationController
  include CardScoped

  def update
    @card.ensure_resolution_record.update!(resolution_record_params)

    respond_to do |format|
      format.turbo_stream { render_card_replacement }
      format.html { redirect_to @card }
      format.json { render json: @card.resolution_record.as_json, status: :ok }
    end
  end

  private
    def resolution_record_params
      permitted = params.expect(card_resolution_record: [
        :problem_description,
        :reproduction_steps,
        :expected_behavior,
        :actual_behavior,
        :environment_context,
        :structured_summary,
        :category,
        :domain,
        :severity,
        :root_cause,
        :fix_summary,
        :verification_steps,
        :verified_at,
        suggested_primitives: [],
        linked_commit_shas: [],
        linked_pr_urls: []
      ])

      permitted.tap do |attributes|
        %i[ suggested_primitives linked_commit_shas linked_pr_urls ].each do |key|
          attributes[key] = normalize_list_param(attributes[key])
        end
      end
    end

    def normalize_list_param(value)
      Array(value).flat_map { it.to_s.split(/[\n,]/) }.map(&:strip).compact_blank
    end
end
