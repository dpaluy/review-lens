require "test_helper"

class ReviewAnalysis::QuestionAnswererTest < ActiveSupport::TestCase
  test "answers allowed questions from built review context" do
    client = AnswerClient.new(
      "answer_markdown" => "Billing support is the clearest pain point.",
      "confidence" => "medium",
      "supporting_review_ids" => [ reviews(:ready_billing).id.to_s, reviews(:negative).id.to_s ],
      "limitations" => [ "Only one billing review matched." ]
    )

    result = ReviewAnalysis::QuestionAnswerer.new(
      product: products(:ready),
      question: "What billing support problems appear?",
      answer_client: client,
      guard_client: GuardClient.new
    ).call

    assert_equal "answered", result.answer_status
    assert_equal "medium", result.confidence
    assert_equal [ reviews(:ready_billing).id.to_s ], result.supporting_review_ids
    assert_equal [ "Only one billing review matched." ], result.limitations
    assert_includes result.answer_markdown, "Billing support"
    assert_includes client.calls.first.fetch(:context_text), "Billing support took three weeks"
  end

  test "strips user-facing metadata labels from answer markdown" do
    client = AnswerClient.new(
      "answer_markdown" => <<~MARKDOWN,
        Billing support is the clearest pain point in the reviews.

        Status: answered
        Confidence: high
        Limitations:
        - Only one billing review matched.
        Supporting reviews: #{reviews(:ready_billing).id}
      MARKDOWN
      "confidence" => "high",
      "supporting_review_ids" => [ reviews(:ready_billing).id.to_s ],
      "limitations" => [ "Only one billing review matched." ]
    )

    result = ReviewAnalysis::QuestionAnswerer.new(
      product: products(:ready),
      question: "What billing support problems appear?",
      answer_client: client,
      guard_client: GuardClient.new
    ).call

    assert_equal "Billing support is the clearest pain point in the reviews.", result.answer_markdown
    assert_equal [ "Only one billing review matched." ], result.limitations
    refute_match(/Status:/, result.answer_markdown)
    refute_match(/Confidence:/, result.answer_markdown)
    refute_match(/Limitations:/, result.answer_markdown)
    refute_match(/Supporting reviews:/, result.answer_markdown)
  end

  test "refuses blocked demo questions before answer generation" do
    client = AnswerClient.new({})

    result = ReviewAnalysis::QuestionAnswerer.new(
      product: products(:ready),
      question: "How do G2 reviews compare?",
      answer_client: client,
      guard_client: GuardClient.new
    ).call

    assert_equal "refused", result.answer_status
    assert_equal "other_review_platform", result.blocked_category
    assert_equal "low", result.confidence
    assert_empty result.supporting_review_ids
assert_empty client.calls
assert_includes result.answer_markdown, "Trustpilot"
refute_match(/corpus/i, result.answer_markdown)
end

test "sanitizes guard refusal reasons before rendering answer text" do
client = AnswerClient.new({})
result = ReviewAnalysis::QuestionAnswerer.new(
product: products(:ready),
question: "What is current weather?",
answer_client: client,
guard_client: RefusingGuardClient.new
).call

assert_equal "refused", result.answer_status
refute_match(/corpus/i, result.answer_markdown)
assert_includes result.answer_markdown, "reviews"
assert_empty client.calls
end

class AnswerClient
    attr_reader :calls

    def initialize(result)
      @result = result
      @calls = []
    end

    def call(product:, question:, context:, context_text:, system_prompt:)
      @calls << { product:, question:, context:, context_text:, system_prompt: }
      @result
    end
end

class GuardClient
    def call(product:, question:, system_prompt:)
      {
        allowed: true,
        blocked_category: "allowed",
        reason: "Question can be answered from the review corpus.",
        safe_rewritten_question: question
      }
end
end

class RefusingGuardClient
def call(product:, question:, system_prompt:)
{
allowed: false,
blocked_category: "outside_knowledge",
reason: "Question requires information outside the review corpus.",
safe_rewritten_question: nil
}
end
end
end
