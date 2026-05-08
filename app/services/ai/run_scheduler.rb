module Ai
  class RunScheduler
    def self.enqueue!(card:, user:, run_type:)
      new(card: card, user: user, run_type: run_type).enqueue!
    end

    def initialize(card:, user:, run_type:)
      @card = card
      @user = user
      @run_type = run_type.to_s
    end

    def enqueue!
      validate_run_type!

      ai_run = AiRun.create!(
        account: card.account,
        card: card,
        user: user,
        run_type: run_type,
        input_context: CardContextBuilder.new(card).build,
        metadata: {
          "queued_by" => "web",
          "queued_at" => Time.current.iso8601
        }
      )

      RunJob.perform_later(ai_run)
      ai_run
    end

    private
      attr_reader :card, :user, :run_type

      def validate_run_type!
        return if AiRun::RUN_TYPES.include?(run_type)

        raise ArgumentError, "Unsupported AI run type: #{run_type}"
      end
  end
end
