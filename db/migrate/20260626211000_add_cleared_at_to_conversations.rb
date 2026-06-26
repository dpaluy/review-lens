class AddClearedAtToConversations < ActiveRecord::Migration[8.1]
  def change
    add_column :conversations, :cleared_at, :datetime
  end
end
