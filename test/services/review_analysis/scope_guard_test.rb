require "test_helper"

class ReviewAnalysis::ScopeGuardTest < ActiveSupport::TestCase
  test "allows corpus-grounded questions through prompt-driven guard client" do
    client = GuardClient.new(
      allowed: true,
      blocked_category: "allowed",
      reason: "The question can be answered from the ingested review corpus.",
      safe_rewritten_question: "Which features do reviewers praise?"
    )

    result = ReviewAnalysis::ScopeGuard.call(
      product: products(:ready),
      question: "Which features do reviewers praise?",
      client:
    )

    assert_predicate result, :allowed?
    assert_equal "allowed", result.blocked_category
    assert_equal "Which features do reviewers praise?", result.safe_rewritten_question
    assert_equal 1, client.calls.size
assert_includes client.calls.first.fetch(:system_prompt), "Trustpilot"
end

test "routes product identity questions through prompt-driven guard client" do
  client = GuardClient.new(
    allowed: true,
    blocked_category: "allowed",
    reason: "The question asks which product these reviews describe.",
    safe_rewritten_question: "What product do these reviews describe?"
  )
  result = ReviewAnalysis::ScopeGuard.call(
    product: products(:ready),
    question: "What product are we talking about?",
    client:
  )

  assert_predicate result, :allowed?
  assert_equal "allowed", result.blocked_category
  assert_equal "What product do these reviews describe?", result.safe_rewritten_question
  assert_equal 1, client.calls.size
end

test "allows broad review relevance questions without prompt over-refusal" do
  client = GuardClient.new(allowed: false)

  result = ReviewAnalysis::ScopeGuard.call(
    product: products(:manual),
    question: "What's most relevant in the review?",
    client:
  )

  assert_predicate result, :allowed?
  assert_equal "allowed", result.blocked_category
  assert_equal "What's most relevant in the review?", result.safe_rewritten_question
  assert_empty client.calls
end

test "refuses mixed product identity and out of scope questions without calling guard client" do
  blocked_questions = {
    "What product are we talking about and what are the current weather conditions?" => "outside_knowledge",
    "What product is this and what are the latest sales numbers?" => "outside_knowledge",
    "What product are we talking about and is it better than Zapier?" => "competitor_comparison"
  }

  blocked_questions.each do |question, category|
    client = GuardClient.new(allowed: true)
    result = ReviewAnalysis::ScopeGuard.call(product: products(:ready), question:, client:)

    assert_not_predicate result, :allowed?, question
    assert_equal category, result.blocked_category, question
    assert_empty client.calls, question
  end
end

test "refuses required blocked demo questions without calling guard client" do
blocked_questions = {
      "How do G2 reviews compare?" => "other_review_platform",
      "What is the current weather?" => "outside_knowledge",
      "Is this better than Zapier?" => "competitor_comparison",
      "What are the latest sales numbers?" => "outside_knowledge",
      "What do Amazon reviews say?" => "external_review_source"
    }

    blocked_questions.each do |question, category|
      client = GuardClient.new(allowed: true)

      result = ReviewAnalysis::ScopeGuard.call(product: products(:ready), question:, client:)

      assert_not_predicate result, :allowed?, question
      assert_equal category, result.blocked_category, question
      assert_includes result.reason, "Trustpilot", question
      assert_nil result.safe_rewritten_question, question
      assert_empty client.calls, question
    end
  end

  test "refuses getapp as another platform for trustpilot corpus" do
    result = ReviewAnalysis::ScopeGuard.call(
      product: products(:ready),
      question: "How do GetApp reviews compare?",
      client: GuardClient.new(allowed: true)
    )

    assert_not_predicate result, :allowed?
    assert_equal "other_review_platform", result.blocked_category
    assert_includes result.reason, "Trustpilot"
  end

  test "does not prefilter valid corpus comparison questions" do
    client = GuardClient.new(
      allowed: true,
      blocked_category: "allowed",
      reason: "The question compares themes within the current review corpus.",
      safe_rewritten_question: "Compare pricing complaints to support complaints in these reviews."
    )

    result = ReviewAnalysis::ScopeGuard.call(
      product: products(:ready),
      question: "Compare pricing complaints to support complaints in these reviews.",
      client:
    )

    assert_predicate result, :allowed?
    assert_equal 1, client.calls.size
  end

  test "names manual import corpus in refusal copy" do
    result = ReviewAnalysis::ScopeGuard.call(
      product: products(:manual),
      question: "What is the current weather?",
      client: GuardClient.new(allowed: true)
    )

    assert_not_predicate result, :allowed?
    assert_equal "outside_knowledge", result.blocked_category
    assert_includes result.reason, "manual import"
  end

  test "normalizes prompt client refusals" do
    client = GuardClient.new(
      "allowed" => false,
      "blocked_category" => "outside_knowledge",
      "reason" => "The question requires information outside the review corpus.",
      "safe_rewritten_question" => "What do reviewers say about pricing?"
    )

    result = ReviewAnalysis::ScopeGuard.call(
      product: products(:ready),
      question: "Should I buy this product?",
      client:
    )

    assert_not_predicate result, :allowed?
    assert_equal "outside_knowledge", result.blocked_category
    assert_equal "The question requires information outside the review corpus.", result.reason
    assert_equal "What do reviewers say about pricing?", result.safe_rewritten_question
  end

  private
    class GuardClient
      attr_reader :calls

      def initialize(result)
        @result = result
        @calls = []
      end

      def call(product:, question:, system_prompt:)
        @calls << { product:, question:, system_prompt: }
        @result
      end
    end
end
