# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

## AI chat foundation

RubyLLM is installed through its Rails generators using `Conversation`,
`ChatMessage`, and `AIModel` as the generated model names. Product-scoped Q&A
lives on `/products/:id`: each product has one persisted conversation enforced
by a unique product conversation index, and product chat submissions reuse it without redirecting analysts to
`/conversations/:id`. Product Q&A uses `ProductConversationResponseJob` and a
product-specific Turbo stream; generated `ConversationResponseJob` remains for
`/internal/conversations`.

Configure provider access with:

* `OPENAI_API_KEY`
* `OPENAI_MODEL` (optional, falls back to RubyLLM's default model)
