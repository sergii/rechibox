require "set"

module Knowledge
  class Retriever
    STRATEGY = "lexical-idf-prefix5-v0.1"
    STOPWORDS = Set.new(%w[
      the and for with from into that this have has had are was were been being
      you your yours our ours their theirs they them then than when where what which
      у в на і й та або але що це я ми ви він вона вони мене мені мій мої моє
      тут там вже ще просто дуже треба потрібно хочу є був була були буде бути для до від з із зі про при по як
    ]).freeze

    def initialize(catalog:, situation:, limit: nil)
      @catalog = catalog
      @situation = situation
      @limit = limit
    end

    def call
      validate_situation!
      query_text = collect_strings(@situation).uniq.join("\n")
      query_tokens = token_list(query_text)
      query_stems = query_tokens.map { |token| stem(token) }.to_set

      locale_stems = @catalog.records.to_h do |record|
        [record.fetch("id"), record.fetch("search_texts").transform_values { |text| stems_for(text) }]
      end
      record_stems = locale_stems.transform_values { |views| views.values.reduce(Set.new, &:|) }
      df = Hash.new(0)
      record_stems.each_value { |stems| stems.each { |value| df[value] += 1 } }

      ranked = @catalog.records.filter_map do |record|
        id = record.fetch("id")
        matched = query_stems & record_stems.fetch(id)
        next if matched.empty?

        score = matched.sum { |value| Math.log((@catalog.records.length + 1.0) / (df.fetch(value) + 1.0)) + 1.0 }
        {
          "id" => id,
          "revision" => record.fetch("revision"),
          "type" => record.fetch("type"),
          "score" => score.round(4),
          "matched_terms" => query_tokens.select { |token| matched.include?(stem(token)) }.uniq.first(20),
          "matched_locales" => locale_stems.fetch(id).filter_map { |locale, stems| locale if !(matched & stems).empty? }
        }
      end.sort_by { |candidate| [-candidate.fetch("score"), candidate.fetch("id")] }

      returned = @limit ? ranked.first(@limit) : ranked
      {
        "contract_version" => "0.1",
        "strategy" => STRATEGY,
        "situation_contract_version" => @situation.fetch("contract_version"),
        "query" => { "text" => query_text, "tokens" => query_tokens.uniq, "limit" => @limit },
        "candidate_count" => ranked.length,
        "returned_count" => returned.length,
        "candidates" => returned
      }
    end

    private

    def validate_situation!
      raise ArgumentError, "situation must be Situation Model v0.1" unless @situation["contract_version"] == "0.1"
    end

    def collect_strings(value, output = [])
      case value
      when Hash then value.each_value { |child| collect_strings(child, output) }
      when Array then value.each { |child| collect_strings(child, output) }
      when String then output << value.strip unless value.strip.empty?
      end
      output
    end

    def token_list(text)
      text.downcase.scan(/\p{L}[\p{L}\p{N}'’-]*/u)
          .map { |token| token.gsub(/\A['’-]+|['’-]+\z/, "") }
          .reject { |token| token.length < 4 || STOPWORDS.include?(token) }
    end

    def stem(token) = token.length > 5 ? token[0, 5] : token
    def stems_for(text) = token_list(text).map { |token| stem(token) }.to_set
  end
end
