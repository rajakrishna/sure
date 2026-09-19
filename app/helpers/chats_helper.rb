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

    if preview_features_enabled?
      commands << { id: "goals", label: t("messages.chat_form.commands.goals"), prompt: t("messages.chat_form.prompts.goals") }
    end

    commands
  end

  def chat_composer_catalog
    Chat::ComposerCatalog.for(Current.user)
  end
end
