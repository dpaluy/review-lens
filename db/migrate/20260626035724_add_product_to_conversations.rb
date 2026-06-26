class AddProductToConversations < ActiveRecord::Migration[8.1]
  def change
    add_reference :conversations, :product, foreign_key: true
  end
end
