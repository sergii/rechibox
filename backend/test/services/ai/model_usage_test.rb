require "test_helper"

class AiModelUsageTest < ActiveSupport::TestCase
  Response = Struct.new(:content, :input_tokens, :output_tokens)

  test "reads token counts and estimates cost from explicit rates" do
    usage = Ai::ModelUsage.from_response(
      Response.new("ok", 1_000, 500),
      input_rate_per_million: "2.00",
      output_rate_per_million: "8.00"
    )

    assert_equal 1_000, usage.fetch("input_tokens")
    assert_equal 500, usage.fetch("output_tokens")
    assert_equal 0.006, usage.fetch("estimated_cost_usd")
  end

  test "keeps estimated cost unknown when pricing is not configured" do
    usage = Ai::ModelUsage.from_response(Response.new("ok", 123, 45))

    assert_equal 123, usage.fetch("input_tokens")
    assert_equal 45, usage.fetch("output_tokens")
    assert_nil usage.fetch("estimated_cost_usd")
  end

  test "supports nested usage hashes" do
    response = Struct.new(:content, :usage).new(
      "ok",
      { "input_tokens" => 10, "output_tokens" => 20 }
    )

    usage = Ai::ModelUsage.from_response(response)

    assert_equal 10, usage.fetch("input_tokens")
    assert_equal 20, usage.fetch("output_tokens")
  end
end
