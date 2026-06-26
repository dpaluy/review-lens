module BatchSummaryClientHelper
  class FakeBatchSummaryClient
    attr_reader :calls

    def initialize(error: nil)
      @error = error
      @calls = []
    end

    def summarize(reviews:)
      calls << reviews
      raise @error if @error

      {
        "pain_points" => [ theme("Slow onboarding", reviews) ],
        "praised_features" => [ theme("Helpful support", reviews) ],
        "feature_requests" => [ theme("Better exports", reviews) ],
        "buyer_objections" => [ theme("Price feels high", reviews) ],
        "sentiment_patterns" => [ theme("Negative reviews mention billing", reviews) ],
        "representative_quotes" => [
          {
            "review_id" => reviews.first[:review_id],
            "quote" => reviews.first[:body],
            "theme" => "billing"
          }
        ],
        "supporting_review_ids" => reviews.map { |review| review[:review_id] }
      }
    end

    private

    def theme(name, reviews)
      {
        "theme" => name,
        "summary" => "#{name} appears in this batch",
        "supporting_review_ids" => reviews.map { |review| review[:review_id] }
      }
    end
  end

  def with_fake_batch_summary_client(error: nil)
    client = FakeBatchSummaryClient.new(error:)
    original_new = ReviewAnalysis::BatchSummarizer::RubyLLMClient.method(:new)

    ReviewAnalysis::BatchSummarizer::RubyLLMClient.define_singleton_method(:new) do |*_args, **_kwargs|
      client
    end

    yield client
  ensure
    ReviewAnalysis::BatchSummarizer::RubyLLMClient.define_singleton_method(:new) do |*args, **kwargs|
      original_new.call(*args, **kwargs)
    end
  end
end

class ActiveSupport::TestCase
  include BatchSummaryClientHelper
end
