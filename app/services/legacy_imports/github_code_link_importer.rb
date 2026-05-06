module LegacyImports
  class GithubCodeLinkImporter
    PR_URL_PATTERN = %r{https?://github\.com/([^/\s]+)/([^/\s]+)/pull/(\d+)}i
    COMMIT_URL_PATTERN = %r{https?://github\.com/([^/\s]+)/([^/\s]+)/commit/([0-9a-f]{7,40})}i

    Result = Data.define(:code_links, :pull_request_urls, :commit_shas)

    def initialize(card:)
      @card = card
    end

    def import(texts)
      code_links = github_references_from(texts).map { import_reference(it) }.compact

      Result.new(
        code_links,
        code_links.filter_map { it.url if it.pull_request? },
        code_links.filter_map { it.sha if it.commit? }
      )
    end

    private
      attr_reader :card

      GithubReference = Data.define(:external_type, :external_id, :repository, :sha, :url)

      def github_references_from(texts)
        Array(texts).compact_blank.flat_map { references_from_text(it.to_s) }.uniq
      end

      def references_from_text(text)
        [
          *text.scan(PR_URL_PATTERN).map { |owner, repo, number| pull_request_reference(owner, repo, number) },
          *text.scan(COMMIT_URL_PATTERN).map { |owner, repo, sha| commit_reference(owner, repo, sha) }
        ]
      end

      def pull_request_reference(owner, repo, number)
        repository = "#{owner}/#{repo}"

        GithubReference.new(
          "pull_request",
          number.to_s,
          repository,
          nil,
          "https://github.com/#{repository}/pull/#{number}"
        )
      end

      def commit_reference(owner, repo, sha)
        repository = "#{owner}/#{repo}"

        GithubReference.new(
          "commit",
          sha,
          repository,
          sha,
          "https://github.com/#{repository}/commit/#{sha}"
        )
      end

      def import_reference(reference)
        Current.with(account: card.account) do
          card.code_links.find_or_initialize_by(
            account: card.account,
            provider: "github",
            external_type: reference.external_type,
            external_id: reference.external_id
          ).tap do |code_link|
            code_link.assign_attributes(
              repository: reference.repository,
              sha: reference.sha,
              title: imported_title_for(reference),
              url: reference.url,
              metadata: code_link.metadata.to_h.merge(
                "source" => "asana_import",
                "repository" => reference.repository
              )
            )
            code_link.save!
          end
        end
      end

      def imported_title_for(reference)
        case reference.external_type
        when "pull_request" then "Imported GitHub PR ##{reference.external_id}"
        when "commit" then "Imported GitHub commit #{reference.sha.to_s.first(12)}"
        end
      end
  end
end
