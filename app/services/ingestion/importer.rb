require "digest"

module Ingestion
  class Importer
    MAX_BODY_LENGTH = 5_000
    THIN_CORPUS_THRESHOLD = 20

    Result = Data.define(:imported, :skipped)

    def self.import(product, parsed_reviews)
      new(product, parsed_reviews).import
    end

    def initialize(product, parsed_reviews)
      @product = product
      @parsed_reviews = parsed_reviews
      @imported = 0
      @skipped = 0
    end

    def import
      parsed_reviews.each { |parsed_review| import_review(parsed_review) }
      update_product_summary

      Result.new(imported:, skipped:)
    end

    private
      attr_reader :product, :parsed_reviews, :imported, :skipped

      def import_review(parsed_review)
        attributes = normalized_attributes(parsed_review)
        return skip_review if attributes[:body].blank?

        review = find_existing_review(attributes) || product.reviews.build
        return skip_review if review.persisted?

        review.assign_attributes(attributes)
        review.save!
        @imported += 1
      rescue ActiveRecord::RecordNotUnique
        skip_review
      end

      def normalized_attributes(parsed_review)
        body = parsed_review[:body].to_s.squish

        {
          external_review_id: parsed_review[:external_review_id].presence,
          content_hash: parsed_review[:content_hash].presence || content_hash_for(parsed_review, body),
          source_url: parsed_review[:source_url],
          rating: parsed_review[:rating],
          title: parsed_review[:title].to_s.squish.presence,
          body: body.truncate(MAX_BODY_LENGTH, omission: ""),
          reviewer_label: parsed_review[:reviewer_label].to_s.squish.presence,
          reviewer_role: parsed_review[:reviewer_role].to_s.squish.presence,
          reviewer_company_size: parsed_review[:reviewer_company_size].to_s.squish.presence,
          review_date: parsed_review[:review_date],
          raw_payload: parsed_review[:raw_payload].presence || {}
        }
      end

      def find_existing_review(attributes)
        if attributes[:external_review_id].present?
          product.reviews.find_by(external_review_id: attributes[:external_review_id])
        else
          product.reviews.find_by(content_hash: attributes[:content_hash])
        end
      end

      def content_hash_for(parsed_review, body)
        Digest::SHA256.hexdigest(
          [
            body,
            parsed_review[:rating],
            parsed_review[:reviewer_label].to_s.squish.presence
          ].compact.join("\n")
        )
      end

      def update_product_summary
        usable_review_count = product.reviews.count
        summary = product.ingestion_summary.merge(
          "usable_review_count" => usable_review_count,
          "corpus_quality" => usable_review_count < THIN_CORPUS_THRESHOLD ? "thin" : "viable"
        )

        product.update_column(:ingestion_summary, summary)
      end

      def skip_review
        @skipped += 1
        nil
      end
  end
end
