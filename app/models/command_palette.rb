class CommandPalette
  Item = Data.define(:name, :path, :icon, :hint, :frame, :data, :auto_submit) do
    def initialize(name:, path:, icon:, hint: nil, frame: nil, data: {}, auto_submit: false)
      super(name: name, path: path, icon: icon, hint: hint, frame: frame, data: data || {}, auto_submit: auto_submit)
    end
  end

  def initialize(user:)
    @user = user
  end

  def items
    [
      Item.new(name: I18n.t("command_palette.home"), path: "/", icon: "home"),
      Item.new(name: I18n.t("command_palette.transactions"), path: "/transactions", icon: "credit-card"),
      Item.new(
        name: I18n.t("command_palette.review"),
        path: "/ai_proposals",
        icon: "sparkles",
        hint: I18n.t("command_palette.review_hint")
      ),
      Item.new(
        name: I18n.t("command_palette.categorize_inbox"),
        path: "/ai_proposals",
        icon: "inbox",
        hint: I18n.t("command_palette.categorize_inbox_hint")
      ),
      Item.new(
        name: I18n.t("command_palette.biggest_expense"),
        path: biggest_expense_path,
        icon: "arrow-up-right",
        hint: I18n.t("command_palette.biggest_expense_hint")
      ),
      Item.new(name: I18n.t("command_palette.plan"), path: "/plan", icon: "compass"),
      Item.new(name: I18n.t("command_palette.cash_flow"), path: "/plan?tab=cash_flow", icon: "arrow-left-right"),
      Item.new(name: I18n.t("command_palette.recurrings"), path: "/plan?tab=bills", icon: "repeat"),
      Item.new(name: I18n.t("command_palette.wealth"), path: "/wealth", icon: "wallet"),
      Item.new(name: I18n.t("command_palette.reports"), path: "/reports", icon: "chart-bar"),
      Item.new(name: I18n.t("command_palette.settings"), path: "/settings/profile", icon: "settings"),
      Item.new(
        name: I18n.t("command_palette.ask"),
        path: "/chats/new",
        icon: "sparkles",
        hint: I18n.t("command_palette.ask_hint"),
        frame: :sidebar_chat,
        data: {
          controller: "ask-link",
          action: "click->app-layout#openRightSidebar click->ask-link#open command-palette#close"
        }
      )
    ]
  end

  private
    attr_reader :user

    def biggest_expense_path
      today = Date.current
      "/transactions?q[types][]=expense&q[start_date]=#{today.beginning_of_month}&q[end_date]=#{today.end_of_month}"
    end
end
