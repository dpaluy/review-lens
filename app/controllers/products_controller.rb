class ProductsController < ApplicationController
  def new
    @product = Product.new
  end

  def show
    @product = Product.find(params[:id])
    @ingestion_run = @product.ingestion_runs.order(:created_at).last

    raise ActiveRecord::RecordNotFound, "Ingestion run missing" unless @ingestion_run
  end

  def create
    Product.transaction do
      @product = Product.find_or_initialize_from_source_url(product_params[:source_url])
      @product.save!
      @product.ingestion_runs.create!
    end

    redirect_to @product
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_content
  end

  private
    def product_params
      params.require(:product).permit(:source_url)
    end
end
