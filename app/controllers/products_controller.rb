class ProductsController < ApplicationController
  def new
    @product = Product.new(import_mode: "url")
  end

  def show
    @product = Product.find(params[:id])
    @ingestion_run = @product.ingestion_runs.order(:created_at).last

    raise ActiveRecord::RecordNotFound, "Ingestion run missing" unless @ingestion_run
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
      Product.transaction do
        @product = Product.find_or_initialize_from_source_url(product_params[:source_url])
        @product.save!
        @product.ingestion_runs.create!
      end
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
end
