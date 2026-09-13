require "json"

module Knowledge
  class Catalog
    def self.default
      path = ENV.fetch("ORGANIZED_RUNTIME_PATH") do
        Rails.root.join("data", "organized-v1.jsonl").to_s
      end

      new(path:)
    end

    attr_reader :records

    def initialize(path:)
      @path = Pathname(path)
      @records = load_records.freeze
      @by_id = @records.index_by { |record| record.fetch("id") }.freeze
    end

    def fetch(id)
      @by_id.fetch(id)
    end

    private

    def load_records
      File.readlines(@path, chomp: true).filter_map do |line|
        next if line.empty?

        JSON.parse(line).tap do |record|
          raise ArgumentError, "unsupported Organized runtime contract" unless record["contract_version"] == 1
          record.fetch("search_texts")
        end
      end
    end
  end
end
