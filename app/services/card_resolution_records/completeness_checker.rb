module CardResolutionRecords
  class CompletenessChecker
    Result = Data.define(
      :record,
      :gate_one_complete,
      :gate_two_complete,
      :missing_gate_one_fields,
      :missing_gate_two_fields,
      :code_evidence_present
    )

    def initialize(record)
      @record = record
    end

    def check
      Result.new(
        record: record,
        gate_one_complete: record.gate_one_complete?,
        gate_two_complete: record.gate_two_complete?,
        missing_gate_one_fields: record.missing_gate_one_fields,
        missing_gate_two_fields: record.missing_gate_two_fields,
        code_evidence_present: record.code_evidence_present?
      )
    end

    private
      attr_reader :record
  end
end
