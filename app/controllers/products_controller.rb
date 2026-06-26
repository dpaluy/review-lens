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

    if @product.reviews_queryable?
      @conversation = @product.conversation!
      @chat_messages = @conversation.chat_messages.order(:created_at, :id)
    end
  end

  def create
    if manual_import?
      create_manual_import
    else
      create_url_import
    end

    redirect_to @product unless performed?
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
      file = product_params[:manual_file]
      unless file.respond_to?(:read)
        @product = Product.new(manual_product_params.merge(import_mode: Product::MANUAL_PLATFORM))
        @product.errors.add(:manual_file, "must be attached")
        render :new, status: :unprocessable_content
        return
      end

      Product.transaction do
        @product = Product.new(
          manual_product_params.merge(
            import_mode: Product::MANUAL_PLATFORM,
            name: manual_name_from(file)
          )
        )
        @product.save!
        ingestion_run = @product.ingestion_runs.create!
        ingestion_run.reviews_file.attach(file)

        IngestManualReviewsJob.perform_later(ingestion_run)
      end
    end

    def manual_name_from(file)
      product_params[:name].presence || File.basename(file.original_filename.to_s, ".*").presence&.humanize
    end

    def manual_import?
      product_params[:import_mode] == Product::MANUAL_PLATFORM
    end

    def product_params
      params.require(:product).permit(:import_mode, :name, :source_url, :manual_file)
    end

    def manual_product_params
      product_params.slice(:name)
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
