class CardResolutionRecords::GateOneGuidance
  PROMPTS = {
    problem_description: "Describe the issue in plain language. What is broken, confusing, or not working?",
    reproduction_steps: "List the exact steps needed to reproduce it. Include page names, buttons, accounts, or inputs when relevant.",
    expected_behavior: "Describe what you expected to happen instead.",
    actual_behavior: "Describe what actually happened, including any error message or wrong result.",
    environment_context: "Add the environment context: product area, UI screen, customer account, browser, device, or data set."
  }.freeze

  Item = Data.define(:field, :label, :prompt)

  def initialize(card)
    @card = card
  end

  def missing_items
    missing_fields.map do |field|
      Item.new(
        field: field,
        label: field.to_s.humanize,
        prompt: PROMPTS.fetch(field)
      )
    end
  end

  def next_item
    missing_items.first
  end

  def complete?
    missing_items.empty?
  end

  private
    attr_reader :card

    def missing_fields
      record.missing_gate_one_fields
    end

    def record
      card.resolution_record || card.build_resolution_record
    end
end
