module WorldState
  class QueryAnswerRenderer
    CONTRACT_VERSION = "0.1"
    STATUSES = %w[resolved ambiguous unknown conflict unavailable].freeze

    def call(message:, query:, resolution:, query_result:)
      locale = detect_locale(message)
      label = query.to_h.dig("entity", "label").to_s.strip

      unless resolution&.fetch("status", nil) == "resolved"
        status = resolution&.fetch("status", nil) == "ambiguous" ? "ambiguous" : "unknown"
        return envelope(status: status, locale: locale, text: resolution_text(status, locale), claim_ids: [])
      end

      return envelope(status: "unavailable", locale: locale, text: nil, claim_ids: []) unless query_result

      intent = query_result.fetch("intent")
      result = query_result.fetch("result")
      rendered = case intent
      when "where_is"
        render_where_is(label, result, locale)
      when "what_is_in"
        render_contents(label, result.fetch("entities"), result.fetch("edges"), locale)
      when "contents_recursive"
        render_contents(label, descendants(result), result.fetch("edges"), locale)
      when "who_owns"
        render_ownership(label, result, locale)
      when "who_has_custody"
        render_custody(label, result, locale)
      else
        raise ArgumentError, "unsupported world query intent"
      end

      envelope(
        status: rendered.fetch(:status),
        locale: locale,
        text: rendered.fetch(:text),
        claim_ids: rendered.fetch(:claim_ids)
      )
    end

    private

    def render_where_is(label, result, locale)
      paths = Array(result["paths"])
      return rendered("unknown", unknown_text("location", label, locale), []) if paths.empty?
      return rendered("ambiguous", ambiguous_location_text(label, locale), claim_ids(paths.flat_map { |path| path["edges"] })) if result["ambiguous"]

      path = paths.first
      edges = Array(path["edges"])
      return rendered("unknown", unknown_text("location", label, locale), []) if edges.empty?
      return rendered("conflict", conflict_location_text(label, locale), claim_ids(edges)) if path["cycle"]

      locations = Array(path["entities"]).drop(1).map { |entity| entity["label"].to_s }.reject(&:empty?)
      return rendered("unknown", unknown_text("location", label, locale), claim_ids(edges)) if locations.empty?

      text = if locale == "uk"
        "Розташування «#{label}»: #{locations.join(" → ")}."
      else
        "Location of “#{label}”: #{locations.join(" → ")}."
      end
      rendered("resolved", text, claim_ids(edges))
    end

    def render_contents(label, entities, edges, locale)
      labels = Array(entities).map { |entity| entity["label"].to_s }.reject(&:empty?)
      return rendered("unknown", unknown_text("contents", label, locale), []) if labels.empty?

      text = if locale == "uk"
        "Вміст «#{label}»: #{labels.join(", ")}."
      else
        "Contents of “#{label}”: #{labels.join(", ")}."
      end
      rendered("resolved", text, claim_ids(edges))
    end

    def render_ownership(label, result, locale)
      labels = Array(result["entities"]).map { |entity| entity["label"].to_s }.reject(&:empty?)
      return rendered("unknown", unknown_text("ownership", label, locale), []) if labels.empty?

      text = if locale == "uk"
        "Власник або власники «#{label}»: #{labels.join(", ")}."
      else
        "Owner or owners of “#{label}”: #{labels.join(", ")}."
      end
      rendered("resolved", text, claim_ids(result["edges"]))
    end

    def render_custody(label, result, locale)
      labels = Array(result["entities"]).map { |entity| entity["label"].to_s }.reject(&:empty?)
      return rendered("unknown", unknown_text("custody", label, locale), []) if labels.empty?
      if labels.size > 1
        text = if locale == "uk"
          "Для «#{label}» є кілька активних записів про зберігання. Потрібне уточнення даних."
        else
          "There are multiple active custody records for “#{label}”. The data needs clarification."
        end
        return rendered("conflict", text, claim_ids(result["edges"]))
      end

      text = if locale == "uk"
        "Зараз «#{label}» зберігає: #{labels.first}."
      else
        "“#{label}” is currently held by: #{labels.first}."
      end
      rendered("resolved", text, claim_ids(result["edges"]))
    end

    def descendants(result)
      root_id = result["root_entity_id"].to_s
      Array(result["nodes"]).reject { |entity| entity["id"].to_s == root_id }
    end

    def unknown_text(kind, label, locale)
      case [locale, kind]
      when ["uk", "location"] then "Розташування «#{label}» поки не записане."
      when ["uk", "contents"] then "Для «#{label}» поки немає записаного вмісту."
      when ["uk", "ownership"] then "Власник «#{label}» поки не записаний."
      when ["uk", "custody"] then "Хто зберігає «#{label}», поки не записано."
      when ["en", "location"] then "The location of “#{label}” is not recorded yet."
      when ["en", "contents"] then "No contents are recorded for “#{label}” yet."
      when ["en", "ownership"] then "The owner of “#{label}” is not recorded yet."
      else "Custody for “#{label}” is not recorded yet."
      end
    end

    def resolution_text(status, locale)
      case [locale, status]
      when ["uk", "ambiguous"] then "Є кілька можливих об'єктів. Потрібне уточнення."
      when ["en", "ambiguous"] then "There are several possible matches. Clarification is needed."
      when ["uk", "unknown"] then "Не вдалося знайти відповідний об'єкт у World State."
      else "No matching entity was found in World State."
      end
    end

    def ambiguous_location_text(label, locale)
      if locale == "uk"
        "Для «#{label}» записано кілька можливих розташувань. Потрібне уточнення."
      else
        "Multiple possible locations are recorded for “#{label}”. Clarification is needed."
      end
    end

    def conflict_location_text(label, locale)
      if locale == "uk"
        "У даних про розташування «#{label}» є цикл. Потрібно виправити World State."
      else
        "The location data for “#{label}” contains a cycle. World State needs correction."
      end
    end

    def detect_locale(message)
      text = message.to_s
      return "uk" if text.match?(/\p{Cyrillic}/u)

      "en"
    end

    def claim_ids(edges)
      Array(edges).filter_map { |edge| edge["claim_id"] }.map(&:to_s).uniq
    end

    def rendered(status, text, claim_ids)
      { status: status, text: text, claim_ids: claim_ids }
    end

    def envelope(status:, locale:, text:, claim_ids:)
      raise ArgumentError, "unsupported answer status" unless STATUSES.include?(status)

      {
        "contract_version" => CONTRACT_VERSION,
        "status" => status,
        "locale" => locale,
        "text" => text,
        "supporting_claim_ids" => claim_ids
      }
    end
  end
end
