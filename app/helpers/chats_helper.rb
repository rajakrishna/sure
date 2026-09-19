module ChatsHelper
  def chat_frame
    :sidebar_chat
  end

  def chat_view_path(chat)
    return new_chat_path if params[:chat_view] == "new"
    return chats_path if chat.nil? || params[:chat_view] == "all"

    chat.persisted? ? chat_path(chat) : new_chat_path
  end

  def chat_slash_commands
    commands = [
      { id: "biggest", label: t("messages.chat_form.commands.biggest"), prompt: t("messages.chat_form.prompts.biggest") },
      { id: "smallest", label: t("messages.chat_form.commands.smallest"), prompt: t("messages.chat_form.prompts.smallest") },
      { id: "income", label: t("messages.chat_form.commands.income"), prompt: t("messages.chat_form.prompts.income") },
      { id: "budget", label: t("messages.chat_form.commands.budget"), prompt: t("messages.chat_form.prompts.budget") },
      { id: "networth", label: t("messages.chat_form.commands.networth"), prompt: t("messages.chat_form.prompts.networth") }
    ]

    commands << { id: "categorize", label: t("messages.chat_form.commands.categorize"), prompt: t("messages.chat_form.prompts.categorize") }
    commands << { id: "recurring", label: t("messages.chat_form.commands.recurring"), prompt: t("messages.chat_form.prompts.recurring") }

    if preview_features_enabled?
      commands << { id: "goals", label: t("messages.chat_form.commands.goals"), prompt: t("messages.chat_form.prompts.goals") }
      commands << { id: "bills", label: t("messages.chat_form.commands.bills"), prompt: t("messages.chat_form.prompts.bills") }
      commands << { id: "insights", label: t("messages.chat_form.commands.insights"), prompt: t("messages.chat_form.prompts.insights") }
    end

    commands
  end

  def chat_composer_catalog
    Chat::ComposerCatalog.for(Current.user)
  end

  def chat_greeting_questions
    questions = []

    briefing = preview_features_enabled? ? Current.family&.weekly_briefings&.recent&.first : nil
    Array(briefing&.suggested_prompts).each do |prompt|
      text = prompt["text"] || prompt[:text]
      next if text.blank?

      questions << { icon: prompt["icon"].presence || "sparkles", text: text }
    end

    defaults = [
      { icon: "chart-area", text: t("chats.ai_greeting.evaluate_portfolio") },
      { icon: "wallet-minimal", text: t("chats.ai_greeting.spending_insights") },
      { icon: "arrow-up-right", text: t("chats.ai_greeting.biggest_expense") },
      { icon: "tag", text: t("chats.ai_greeting.categorize") },
      { icon: "alert-triangle", text: t("chats.ai_greeting.unusual_patterns") }
    ]

    if preview_features_enabled?
      defaults += [
        { icon: "sparkles", text: t("chats.ai_greeting.insights") },
        { icon: "repeat", text: t("chats.ai_greeting.bills") },
        { icon: "store", text: t("chats.ai_greeting.merchants") }
      ]
    end

    defaults.each do |question|
      next if questions.any? { |existing| existing[:text] == question[:text] }

      questions << question
    end

    questions.first(6)
  end

  def chat_tool_presentations(assistant_message)
    assistant_message.tool_calls.filter_map do |tool_call|
      result = tool_call.function_result
      next unless result.is_a?(Hash)

      payload = result.with_indifferent_access
      chart = payload[:chart]
      deep_links = Array(payload[:deep_links])
      next if chart.blank? && deep_links.empty?

      { chart: chart, deep_links: deep_links }
    end
  end
end
