require "securerandom"
require "time"

module Conversations
  class Reply
    def initialize(conversation_id:, message:, limit: nil, store: Store.default)
      @conversation_id = conversation_id
      @message = message.to_s.strip
      @limit = limit
      @store = store
    end

    def call
      raise ArgumentError, "message must not be blank" if @message.empty?

      conversation = @store.fetch(@conversation_id)
      history = conversation.fetch("messages").map do |message|
        {
          "role" => message.fetch("role"),
          "text" => message.fetch("text")
        }
      end

      advice = Advice::Generate.new(
        message: @message,
        history: history,
        limit: @limit
      ).call

      new_messages = [build_message(role: "user", text: @message)]
      if advice["answer"]
        new_messages << build_message(
          role: "assistant",
          text: advice.fetch("answer"),
          trace_id: advice["trace_id"]
        )
      end

      updated = @store.append(id: @conversation_id, messages: new_messages)

      {
        "conversation" => updated,
        "advice" => advice
      }
    end

    private

    def build_message(role:, text:, trace_id: nil)
      {
        "id" => SecureRandom.uuid,
        "role" => role,
        "text" => text,
        "created_at" => Time.now.utc.iso8601(6),
        "trace_id" => trace_id
      }
    end
  end
end
