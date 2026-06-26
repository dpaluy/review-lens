class EnforceOneConversationPerProduct < ActiveRecord::Migration[8.1]
  def up
    duplicate_product_ids.each do |product_id|
      conversation_ids = select_values(<<~SQL.squish)
        SELECT id
        FROM conversations
        WHERE product_id = #{quote(product_id)}
        ORDER BY id ASC
      SQL

      keeper_id, *duplicate_ids = conversation_ids
      next if duplicate_ids.empty?

      quoted_duplicate_ids = duplicate_ids.map { |id| quote(id) }.join(", ")

      execute <<~SQL.squish
        UPDATE chat_messages
        SET conversation_id = #{quote(keeper_id)}
        WHERE conversation_id IN (#{quoted_duplicate_ids})
      SQL

      execute <<~SQL.squish
        DELETE FROM conversations
        WHERE id IN (#{quoted_duplicate_ids})
      SQL
    end

    add_index :conversations,
      :product_id,
      unique: true,
      where: "product_id IS NOT NULL",
      name: "index_conversations_on_unique_product_id"
  end

  def down
    remove_index :conversations, name: "index_conversations_on_unique_product_id"
  end

  private

  def duplicate_product_ids
    select_values(<<~SQL.squish)
      SELECT product_id
      FROM conversations
      WHERE product_id IS NOT NULL
      GROUP BY product_id
      HAVING COUNT(*) > 1
    SQL
  end
end
