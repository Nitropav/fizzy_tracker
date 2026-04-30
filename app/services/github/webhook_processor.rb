module Github
  class WebhookProcessor
    def initialize(account:, event:, payload:)
      @account = account
      @event = event.to_s
      @payload = payload
    end

    def process
      case event
      when "push" then process_push
      when "pull_request" then process_pull_request
      else []
      end
    end

    private
      attr_reader :account, :event, :payload

      def process_push
        Array(payload["commits"]).flat_map { |commit| link_commit(commit) }
      end

      def process_pull_request
        pull_request = payload["pull_request"] || {}
        link_pull_request(pull_request)
      end

      def link_commit(commit)
        link_cards_for(
          texts: [ commit["message"], branch_name ],
          external_type: "commit",
          external_id: commit.fetch("id"),
          sha: commit["id"],
          title: commit["message"].to_s.lines.first.to_s.strip,
          url: commit["url"],
          metadata: {
            "author" => commit["author"],
            "timestamp" => commit["timestamp"],
            "branch" => branch_name,
            "github_event" => event
          }
        )
      end

      def link_pull_request(pull_request)
        link_cards_for(
          texts: [ pull_request["title"], pull_request["body"], pull_request.dig("head", "ref") ],
          external_type: "pull_request",
          external_id: pull_request.fetch("number").to_s,
          sha: pull_request.dig("head", "sha"),
          title: pull_request["title"],
          url: pull_request["html_url"],
          metadata: {
            "action" => payload["action"],
            "state" => pull_request["state"],
            "branch" => pull_request.dig("head", "ref"),
            "github_event" => event
          }
        )
      end

      def link_cards_for(texts:, external_type:, external_id:, sha:, title:, url:, metadata:)
        card_numbers = TicketReferenceParser.new(*texts).card_numbers
        return [] if card_numbers.empty?

        account.cards.where(number: card_numbers).map do |card|
          card.code_links.find_or_initialize_by(
            account: account,
            provider: "github",
            external_type: external_type,
            external_id: external_id
          ).tap do |code_link|
            code_link.assign_attributes(
              repository: repository_name,
              sha: sha,
              title: title,
              url: url,
              metadata: metadata.merge("repository" => repository_name)
            )
            code_link.save!
          end
        end
      end

      def repository_name
        payload.dig("repository", "full_name")
      end

      def branch_name
        payload["ref"].to_s.delete_prefix("refs/heads/")
      end
  end
end
