module WorldState
  class ResolveEntities
    CONTRACT_VERSION = "0.1"
    STOPWORDS = %w[
      a an and are as at be by for from in is it of on or the this that these those to with
      це ця цей ці та і й у в на з із зі до від для по при про як що
    ].freeze
    RESOLUTION_THRESHOLD = 0.85
    AMBIGUITY_MARGIN = 0.15

    def initialize(world:, situation:)
      @world = world.to_h
      @situation = situation.to_h
    end

    def call
      {
        "contract_version" => CONTRACT_VERSION,
        "world_id" => @world.fetch("id"),
        "resolutions" => Array(@situation["entities"]).map { |entity| resolve(entity) }
      }
    end

    private

    def resolve(entity)
      situation_entity = entity.to_h.transform_keys(&:to_s)
      ref = situation_entity.fetch("ref").to_s
      kind = situation_entity.fetch("kind", "other").to_s
      label = situation_entity.fetch("label").to_s.strip
      candidates = candidate_entities(kind: kind).map do |candidate|
        score_candidate(label: label, candidate: candidate)
      end.select { |candidate| candidate.fetch("score").positive? }
        .sort_by { |candidate| [-candidate.fetch("score"), candidate.fetch("entity_id")] }

      status, durable_entity_id = classify(candidates)

      {
        "situation_entity_ref" => ref,
        "kind" => kind,
        "label" => label,
        "status" => status,
        "durable_entity_id" => durable_entity_id,
        "candidates" => candidates.first(5)
      }
    end

    def candidate_entities(kind:)
      Array(@world["entities"]).select do |entity|
        candidate_kind = entity.fetch("kind", "other").to_s
        kind == "other" || candidate_kind == kind
      end
    end

    def score_candidate(label:, candidate:)
      names = [candidate["label"], *Array(candidate["aliases"])].compact.map(&:to_s)
      scores = names.map { |name| similarity(label, name) }
      score = scores.max || 0.0

      {
        "entity_id" => candidate.fetch("id"),
        "label" => candidate.fetch("label"),
        "kind" => candidate.fetch("kind", "other"),
        "score" => score.round(4),
        "match" => match_type(label, names, score)
      }
    end

    def classify(candidates)
      best = candidates[0]
      return ["unresolved", nil] unless best
      return ["unresolved", nil] if best.fetch("score") < RESOLUTION_THRESHOLD

      second = candidates[1]
      if second && (best.fetch("score") - second.fetch("score")) < AMBIGUITY_MARGIN
        return ["ambiguous", nil]
      end

      ["resolved", best.fetch("entity_id")]
    end

    def similarity(left, right)
      left_normalized = normalize(left)
      right_normalized = normalize(right)
      return 0.0 if left_normalized.empty? || right_normalized.empty?
      return 1.0 if left_normalized == right_normalized

      left_tokens = tokens(left_normalized)
      right_tokens = tokens(right_normalized)
      return 0.0 if left_tokens.empty? || right_tokens.empty?

      overlap = (left_tokens & right_tokens).size
      return 0.0 if overlap.zero?
      return 0.0 if overlap == 1 && [left_tokens.size, right_tokens.size].max > 1

      containment = overlap.to_f / [left_tokens.size, right_tokens.size].min
      jaccard = overlap.to_f / (left_tokens | right_tokens).size
      ((containment * 0.7) + (jaccard * 0.3)).round(4)
    end

    def match_type(label, names, score)
      return "none" if score.zero?
      return "exact" if names.any? { |name| normalize(name) == normalize(label) }

      "token_overlap"
    end

    def normalize(value)
      value.to_s.downcase.unicode_normalize(:nfkc).gsub(/[^\p{L}\p{N}]+/u, " ").strip
    end

    def tokens(value)
      value.split.reject { |token| STOPWORDS.include?(token) }
    end
  end
end
