class AIModel < ApplicationRecord
  acts_as_model chats: :conversations
end
