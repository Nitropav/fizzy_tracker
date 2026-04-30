module Search::Record::PostgreSQL
  extend ActiveSupport::Concern

  SHARD_COUNT = 16

  included do
    self.abstract_class = true
    before_save :set_account_key

    scope :matching, ->(query, account_id) do
      terms = query.to_s.split
      terms.reduce(where(account_id: account_id)) do |scope, term|
        pattern = "%#{sanitize_sql_like(term.downcase)}%"
        scope.where(
          "LOWER(COALESCE(#{table_name}.title, '')) LIKE :pattern OR LOWER(COALESCE(#{table_name}.content, '')) LIKE :pattern",
          pattern: pattern
        )
      end
    end

    SHARD_CLASSES = SHARD_COUNT.times.map do |shard_id|
      Class.new(self) do
        self.table_name = "search_records_#{shard_id}"

        def self.name
          "Search::Record"
        end
      end
    end.freeze
  end

  class_methods do
    def shard_id_for_account(account_id)
      Zlib.crc32(account_id.to_s) % SHARD_COUNT
    end

    def search_fields(query)
      "#{connection.quote(query.terms)} AS query"
    end

    def for(account_id)
      SHARD_CLASSES[shard_id_for_account(account_id)]
    end
  end

  def card_title
    highlight(card.title, show: :full) if card_id
  end

  def card_description
    highlight(card.description.to_plain_text, show: :snippet) if card_id
  end

  def comment_body
    highlight(comment.body.to_plain_text, show: :snippet) if comment
  end

  private
    def set_account_key
      self.account_key = "account#{account_id}"
    end

    def highlight(text, show:)
      if text.present? && attribute?(:query)
        highlighter = Search::Highlighter.new(query)
        show == :snippet ? highlighter.snippet(text) : highlighter.highlight(text)
      else
        text
      end
    end
end
