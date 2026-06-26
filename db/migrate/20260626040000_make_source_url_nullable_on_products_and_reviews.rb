class MakeSourceUrlNullableOnProductsAndReviews < ActiveRecord::Migration[8.1]
  def change
    change_column_null :products, :source_url, true
    change_column_null :reviews, :source_url, true
  end
end
