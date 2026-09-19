class ChatsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_chat, only: [ :show, :edit, :update, :destroy ]

  def index
    @chat = nil # override application_controller default behavior of setting @chat to last viewed chat
    @chats = Current.user.chats.order(created_at: :desc)
  end

  def show
    set_last_viewed_chat(@chat)
  end

  def new
    @chat = Current.user.chats.new(
      title: t(".default_title", timestamp: Time.current.strftime("%Y-%m-%d %H:%M"))
    )
    @message_hint = params[:message_hint]
    @composer_seed = parse_composer_seed(params[:composer_context])
  end

  def create
    attachments = Array(chat_params[:attachments]).compact_blank
    content = Chat::ComposerContext.merge(
      chat_params[:content],
      chat_params[:composer_context],
      user: Current.user,
      attachments: attachments
    )
    content = I18n.t("messages.chat_form.attached_only") if content.blank? && attachments.any?

    @chat = Current.user.chats.start!(content, model: chat_params[:ai_model], attachments: attachments)
    set_last_viewed_chat(@chat)
    redirect_to chat_path(@chat, thinking: true)
  end

  def edit
  end

  def update
    @chat.update!(params.require(:chat).permit(:title))

    respond_to do |format|
      format.html { redirect_back_or_to chat_path(@chat), notice: t(".success") }
      format.turbo_stream { render turbo_stream: turbo_stream.replace(dom_id(@chat, :title), partial: "chats/chat_title", locals: { chat: @chat }) }
    end
  end

  def destroy
    @chat.destroy
    clear_last_viewed_chat

    redirect_to chats_path, notice: t(".notice")
  end

  def retry
    @chat.retry_last_message!
    redirect_to chat_path(@chat)
  end

  private
    def set_chat
      @chat = Current.user.chats.find(params[:id])
    end

    def set_last_viewed_chat(chat)
      Current.user.update!(last_viewed_chat: chat)
    end

    def clear_last_viewed_chat
      Current.user.update!(last_viewed_chat: nil)
    end

    def chat_params
      params.require(:chat).permit(:title, :content, :ai_model, :composer_context, attachments: [])
    end

    def parse_composer_seed(raw)
      parsed = raw.is_a?(String) && raw.present? ? JSON.parse(raw) : raw
      Array(parsed).select { |item| item.is_a?(Hash) }
    rescue JSON::ParserError, TypeError
      []
    end
end
