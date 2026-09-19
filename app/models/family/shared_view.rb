class Family::SharedView
  Option = Data.define(:key, :label, :user_id)

  def self.options_for(family)
    members = family.users.where.not(role: %w[guest]).order(:first_name, :email)
    [ Option.new(key: "ours", label: I18n.t("shared_views.ours"), user_id: nil) ] +
      members.map do |member|
        Option.new(
          key: "member:#{member.id}",
          label: member.first_name.presence || member.email,
          user_id: member.id
        )
      end
  end

  def initialize(family:, user:, key:)
    @family = family
    @user = user
    @key = normalize(key)
  end

  def key
    @key
  end

  def ours?
    @key == "ours"
  end

  def member_id
    return if ours?

    @key.delete_prefix("member:")
  end

  def account_ids
    scope = user.finance_accounts
    return scope.pluck(:id) if ours?

    scope.where(owner_id: member_id).pluck(:id)
  end

  def label
    self.class.options_for(family).find { |option| option.key == @key }&.label ||
      I18n.t("shared_views.ours")
  end

  private
    attr_reader :family, :user

    def normalize(raw)
      candidate = raw.to_s
      return "ours" if candidate.blank? || candidate == "ours"
      return candidate if candidate.start_with?("member:") && family.users.exists?(id: candidate.delete_prefix("member:"))

      "ours"
    end
end
