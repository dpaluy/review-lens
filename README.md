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
`ChatMessage`, and `AIModel` as the generated model names. The generated chat UI
is available at `/conversations`.

Configure provider access with:

* `OPENAI_API_KEY`
* `OPENAI_MODEL` (optional, falls back to RubyLLM's default model)

This branch only provides the generic RubyLLM chat foundation. Product-scoped,
review-grounded Q&A and guardrails still need to be layered onto the
conversation flow before demo use.
