class ReceiptVisionJob < ApplicationJob
  queue_as :medium_priority

  def perform(transaction_id)
    transaction = Transaction.find_by(id: transaction_id)
    return unless transaction
    return unless transaction.splittable?
    return unless transaction.entry.account.family.preview_features_enabled?

    Family::ReceiptParser.new(family: transaction.entry.account.family, transaction: transaction).propose!
  rescue => e
    DebugLogEntry.capture(
      category: "receipt_vision",
      level: "error",
      message: "Receipt vision failed: #{e.class}: #{e.message}",
      source: self.class.name,
      family: transaction&.entry&.account&.family,
      metadata: { transaction_id: transaction_id }
    )
  end
end
