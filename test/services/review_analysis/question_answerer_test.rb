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
end
