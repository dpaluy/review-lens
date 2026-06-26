class ProductsController < ApplicationController
  def new
    @product = Product.new(import_mode: "url")
  end

  def show
    @product = Product.find(params[:id])
    @ingestion_run = @product.ingestion_runs.order(:created_at).last

    raise ActiveRecord::RecordNotFound, "Ingestion run missing" unless @ingestion_run

    if @product.ready? && @product.reviews_count > 0
      @sample_reviews = @product.reviews.order(rating: :desc, created_at: :asc).limit(10)
      @field_coverage = compute_field_coverage
    end

    @chat_messages = (session.dig(:chat, @product.id.to_s) || [])
  end

  def create
    if manual_import?
      create_manual_import
    else
      create_url_import
    end

    redirect_to @product
  rescue ActiveRecord::RecordInvalid => error
    @product = error.record
    render :new, status: :unprocessable_content
  end

  private
    def create_url_import
      ingestion_run = nil

      Product.transaction do
        @product = Product.find_or_initialize_from_source_url(product_params[:source_url])
        @product.save!
        ingestion_run = @product.ingestion_runs.create!
      end

      IngestReviewsJob.perform_later(ingestion_run)
    end

    def create_manual_import
      Product.transaction do
        @product = Product.new(manual_product_params.merge(import_mode: Product::MANUAL_PLATFORM))
        @product.save!
        ingestion_run = @product.ingestion_runs.create!

        Ingestion::ManualImport.new(
          product: @product,
          ingestion_run:,
          pasted_reviews: product_params[:manual_reviews]
        ).call
      end
    end

    def manual_import?
      product_params[:import_mode] == Product::MANUAL_PLATFORM
    end

    def product_params
      params.require(:product).permit(:import_mode, :name, :source_url, :manual_reviews)
    end

    def manual_product_params
      product_params.slice(:name, :source_url)
    end

    def compute_field_coverage
      total = @product.reviews_count.to_f
      return [] if total.zero?

      reviews = @product.reviews
      rows = [
        [ "Star rating",    reviews.where.not(rating: nil).count ],
        [ "Review title",   reviews.where.not(title: [ nil, "" ]).count ],
        [ "Body text",      reviews.where.not(body: [ nil, "" ]).count ],
        [ "Author name",    reviews.where.not(reviewer_label: [ nil, "" ]).count ],
        [ "Review date",    reviews.where.not(review_date: nil).count ],
        [ "Reviewer role",  reviews.where.not(reviewer_role: [ nil, "" ]).count ],
        [ "Company size",   reviews.where.not(reviewer_company_size: [ nil, "" ]).count ]
      ]

      rows.map do |field, count|
        pct = (count / total * 100).round
        bar_color = pct >= 80 ? "#1f8a5b" : pct >= 40 ? "#c08a1e" : "#c2c6cc"
        ink_color  = pct >= 80 ? "#166b47" : pct >= 40 ? "#8a5e10" : "#8a9099"
        { field:, pct:, bar_color:, ink_color: }
      end
    end
end
