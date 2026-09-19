class CommandPalette
  Item = Data.define(:name, :path, :icon, :hint)

  def initialize(user:)
    @user = user
  end

  def items
    [
      Item.new(name: I18n.t("command_palette.home"), path: "/", icon: "home", hint: nil),
      Item.new(name: I18n.t("command_palette.transactions"), path: "/transactions", icon: "credit-card", hint: nil),
      Item.new(name: I18n.t("command_palette.review"), path: "/ai_proposals", icon: "sparkles", hint: I18n.t("command_palette.review_hint")),
      Item.new(name: I18n.t("command_palette.inbox"), path: "/transactions/inbox", icon: "inbox", hint: nil),
      Item.new(name: I18n.t("command_palette.plan"), path: "/plan", icon: "compass", hint: nil),
      Item.new(name: I18n.t("command_palette.cash_flow"), path: "/plan?tab=cash_flow", icon: "arrow-left-right", hint: nil),
      Item.new(name: I18n.t("command_palette.recurrings"), path: "/recurring_transactions/board", icon: "repeat", hint: nil),
      Item.new(name: I18n.t("command_palette.wealth"), path: "/wealth", icon: "wallet", hint: nil),
      Item.new(name: I18n.t("command_palette.reports"), path: "/reports", icon: "chart-bar", hint: nil),
      Item.new(name: I18n.t("command_palette.settings"), path: "/settings/profile", icon: "settings", hint: nil),
      Item.new(name: I18n.t("command_palette.ask"), path: "/chats/new", icon: "sparkles", hint: I18n.t("command_palette.ask_hint"))
    ]
  end

  private
    attr_reader :user
end
