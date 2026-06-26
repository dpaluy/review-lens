module ReviewAnalysis
  class QuestionAnswerer
    ANSWER_STATUS_ANSWERED = "answered"
    ANSWER_STATUS_REFUSED = "refused"
    CONFIDENCE_VALUES = %w[ high medium low ].freeze

    ANSWER_SCHEMA = {
      name: "reviewlens_grounded_answer",
      strict: true,
      schema: {
        type: "object",
        additionalProperties: false,
        required: %w[ answer_markdown confidence supporting_review_ids limitations ],
        properties: {
          answer_markdown: { type: "string" },
          confidence: { type: "string", enum: CONFIDENCE_VALUES },
          supporting_review_ids: { type: "array", items: { type: "string" } },
          limitations: { type: "array", items: { type: "string" } }
        }
      }
    }.freeze

    SYSTEM_PROMPT = <<~PROMPT.squish
      You are ReviewLens AI. Answer only from the supplied product review context.
      Use review IDs exactly as supplied. Do not use outside knowledge, browsing,
      competitors, other platforms, market facts, or generic product claims.
      If the context does not support a claim, state the limitation instead.
    PROMPT

    Result = Data.define(
      :answer_markdown,
      :confidence,
      :supporting_review_ids,
      :limitations,
      :answer_status,
      :blocked_category,
      :reason
    )

    class RubyLlmClient
      def call(product:, question:, context:, context_text:, system_prompt:)
        response = RubyLLM.chat
          .with_instructions(system_prompt)
          .with_schema(ANSWER_SCHEMA)
          .ask(user_prompt(product:, question:, context_text:))

        response.content
      end

      private
        def user_prompt(product:, question:, context_text:)
          <<~PROMPT
            Product: #{product.name}
            Platform: #{ScopeGuard.platform_label(product)}
            Question: #{question}

            Review context:
            #{context_text}
          PROMPT
        end
    end

    def self.call(product:, question:, answer_client: RubyLlmClient.new, guard_client: ScopeGuard::RubyLlmClient.new)
      new(product:, question:, answer_client:, guard_client:).call
    end

    def initialize(product:, question:, answer_client: RubyLlmClient.new, guard_client: ScopeGuard::RubyLlmClient.new)
      @product = product
      @question = question.to_s.squish
      @answer_client = answer_client
      @guard_client = guard_client
    end

    def call
      guard_result = ScopeGuard.call(product:, question:, client: guard_client)
      return refusal_result(guard_result) unless guard_result.allowed?

      guarded_question = guard_result.safe_rewritten_question.presence || question
      context = ContextBuilder.new(product:, question: guarded_question).call
      normalize_answer(answer_client.call(
        product:,
        question: guarded_question,
        context: context.data,
        context_text: context.text,
        system_prompt: SYSTEM_PROMPT
      ), context)
    end

    private
      attr_reader :product, :question, :answer_client, :guard_client

      def normalize_answer(answer, context)
        answer = answer.to_h.stringify_keys
        supporting_review_ids = Array(answer["supporting_review_ids"]).map(&:to_s) & context.review_ids.map(&:to_s)

        Result.new(
          answer_markdown: answer["answer_markdown"].to_s,
          confidence: normalize_confidence(answer["confidence"]),
          supporting_review_ids:,
          limitations: Array(answer["limitations"]).map(&:to_s),
          answer_status: ANSWER_STATUS_ANSWERED,
          blocked_category: nil,
          reason: nil
        )
      end

      def refusal_result(guard_result)
        Result.new(
          answer_markdown: refusal_text(guard_result),
          confidence: "low",
          supporting_review_ids: [],
          limitations: [ guard_result.reason ],
          answer_status: ANSWER_STATUS_REFUSED,
          blocked_category: guard_result.blocked_category,
          reason: guard_result.reason
        )
      end

      def refusal_text(guard_result)
        platform = ScopeGuard.platform_label(product)

        "I cannot answer that from the current #{platform} review corpus. #{guard_result.reason}"
      end

      def normalize_confidence(confidence)
        CONFIDENCE_VALUES.include?(confidence.to_s) ? confidence.to_s : "low"
      end
  end
end
