require "test_helper"
require "json"
require "tmpdir"

class AiTraceRecordersJsonlTest < ActiveSupport::TestCase
  test "appends one trace as JSONL and returns its id" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "ai-runs.jsonl")
      recorder = Ai::TraceRecorders::Jsonl.new(path: path)
      trace = {
        "trace_version" => "0.1",
        "id" => "trace-1",
        "raw_input" => "Перекладаю коробки"
      }

      assert_equal "trace-1", recorder.record(trace: trace)
      assert_equal trace, JSON.parse(File.read(path))
    end
  end

  test "requires an explicit path" do
    error = assert_raises(ArgumentError) { Ai::TraceRecorders::Jsonl.new(path: "") }

    assert_match "AI_TRACE_PATH", error.message
  end
end
