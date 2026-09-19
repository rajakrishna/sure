# Naive-Bayes transaction categorizer.
#
# Trains a multinomial naive-Bayes model (Laplace add-1 smoothing) on the
# family's already-categorized transactions, then classifies uncategorized
# ones from the same token signals the LLM categorizer uses
# (entry name + notes + merchant name). Unlike AutoCategorizer it needs no
# provider — pure Ruby, trained on the fly and memoized per instance.
class Family::BayesCategorizer
  CONFIDENCE_THRESHOLD = 0.7
  MIN_TRAINING_TRANSACTIONS = 20
  MIN_CATEGORIES = 2
  # The whole training set is held in memory, so cap it rather than loading a
  # long-lived family's entire history on every categorization run. The most
  # recent transactions are also the most representative of current spending.
  MAX_TRAINING_TRANSACTIONS = 5_000

  # categorized_ids: transaction ids the model labeled at/above threshold
  # (regardless of whether the write actually changed anything).
  # modified_count: how many of those writes changed the category.
  Result = Data.define(:categorized_ids, :modified_count)

  def initialize(family)
    @family = family
  end

  # Guard: refuse to classify until there's a real signal to train on.
  def enough_training_data?
    training_transactions.size >= MIN_TRAINING_TRANSACTIONS &&
      training_transactions.map(&:category_id).uniq.size >= MIN_CATEGORIES
  end

  # Returns [category_id, confidence] for the argmax category, or nil when
  # the model isn't trained yet or no category clears the confidence
  # threshold (below threshold = no confident answer).
  def classify(transaction)
    top = classify_candidates(transaction).first
    return nil unless top
    return nil if top[:confidence] < confidence_threshold

    [ top[:category_id], top[:confidence] ]
  end

  def classify_candidates(transaction, limit: 2)
    return [] unless enough_training_data?

    log_scores = log_scores_for(tokens_for(transaction))
    return [] if log_scores.empty?

    probabilities = softmax(log_scores.values)
    ranked = log_scores.keys.zip(probabilities).sort_by { |_, confidence| -confidence }
    ranked.first(limit).map { |category_id, confidence| { category_id: category_id, confidence: confidence } }
  end

  # Labels every uncategorized, enrichable transaction in transaction_ids
  # whose argmax confidence clears the threshold. No-op (empty Result) when
  # the training guard fails.
  def classify_and_apply(transaction_ids)
    return Result.new(categorized_ids: [], modified_count: 0) unless enough_training_data?

    categorized_ids = []
    modified_count = 0

    family.transactions
          .where(id: transaction_ids, category_id: nil)
          .enrichable(:category_id)
          .includes(:category, :merchant, :entry)
          .find_each do |transaction|
      candidates = classify_candidates(transaction)
      top = candidates.first
      next unless top

      category_id = top[:category_id]
      confidence = top[:confidence]
      alternatives = candidates.drop(1).filter_map do |candidate|
        alt = family.categories.find_by(id: candidate[:category_id])
        next unless alt

        { "category_id" => alt.id, "category_name" => alt.name, "confidence" => candidate[:confidence] }
      end

      categorized_ids << transaction.id if confidence >= confidence_threshold
      was_proposed = AiProposal.propose_categorize!(
        family: family,
        transaction: transaction,
        category_id: category_id,
        source: "bayes",
        confidence: confidence,
        reason: I18n.t("ai_proposals.reasons.bayes"),
        alternatives: alternatives
      )
      maybe_auto_apply!(transaction, category_id, confidence) if was_proposed
      modified_count += 1 if was_proposed
    end

    Result.new(categorized_ids: categorized_ids, modified_count: modified_count)
  end

  private
    attr_reader :family

    # Same signal composition as AutoCategorizer#transactions_input, so the
    # two categorizers agree on what text a transaction speaks.
    def tokens_for(transaction)
      [ transaction.entry&.name, transaction.entry&.notes, transaction.merchant&.name ]
        .compact
        .join(" ")
        .downcase
        .scan(/[a-z0-9]+/)
    end

    def training_transactions
      @training_transactions ||= family.transactions
                                      .where.not(category_id: nil)
                                      .includes(:category, :merchant, :entry)
                                      .order(created_at: :desc)
                                      .limit(MAX_TRAINING_TRANSACTIONS)
                                      .to_a
    end

    # Per-category token-count models: { category_id => { total:, counts: } }.
    def class_models
      @class_models ||= training_transactions.group_by(&:category_id).transform_values do |txns|
        counts = Hash.new(0)
        txns.each { |txn| tokens_for(txn).each { |token| counts[token] += 1 } }
        { total: counts.values.sum, counts: counts }
      end
    end

    def vocabulary
      @vocabulary ||= Set.new(class_models.values.flat_map { |model| model[:counts].keys })
    end

    # Multinomial NB log-score per category with Laplace add-1 smoothing and
    # a uniform prior (constant across classes, so it drops out of softmax).
    # log(P(c)) + Σ_tokens log((count_t + 1) / (total + |V|))
    def log_scores_for(tokens)
      # Score only tokens the model has actually seen. An unknown token's
      # smoothed likelihood is 1/(total_c + |V|), which varies with the class's
      # own token count, so keeping them would let a wholly novel description
      # accumulate confidence for whichever category simply has the smallest
      # corpus. Dropping them leaves nothing to score, which is the honest
      # answer: no known signal, no classification, fall through to the LLM.
      known_tokens = tokens.select { |token| vocabulary.include?(token) }
      return {} if known_tokens.empty? || class_models.empty?

      denominator = vocabulary.size
      class_models.each_with_object({}) do |(category_id, model), scores|
        score = Math.log(1.0 / class_models.size)
        score += known_tokens.sum do |token|
          count = model[:counts][token] || 0
          Math.log((count + 1).to_f / (model[:total] + denominator))
        end
        scores[category_id] = score
      end
    end

    # Numerically stable softmax over the log-scores.
    def confidence_threshold
      family.respond_to?(:bayes_confidence_threshold) ? family.bayes_confidence_threshold : CONFIDENCE_THRESHOLD
    end

    def maybe_auto_apply!(transaction, category_id, confidence)
      return unless family.high_confidence_auto_apply?
      return unless family.intelligence_unlocked?
      return unless confidence.to_f >= 0.9

      actor = family.users.where(role: %w[admin super_admin]).first || family.users.first
      proposal = family.ai_proposals.pending.find_by(kind: "categorize", target_id: transaction.id)
      proposal&.approve!(actor) if actor
    end

    def softmax(scores)
      max = scores.max
      exps = scores.map { |score| Math.exp(score - max) }
      sum = exps.sum
      exps.map { |exp| exp / sum }
    end
end
