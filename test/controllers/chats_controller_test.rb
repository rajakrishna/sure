require "test_helper"

class ChatsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @family = families(:dylan_family)
    sign_in @user
  end

  test "index restores the last viewed chat" do
    chat = chats(:one)
    @user.update!(last_viewed_chat: chat)

    get chats_url

    assert_redirected_to chat_path(chat)
  end

  test "index opens a new chat when the user has none" do
    @user.chats.destroy_all
    @user.update!(last_viewed_chat: nil)

    get chats_url

    assert_redirected_to new_chat_path
  end

  test "gets new chat with a localized German default title" do
    @user.update!(locale: "de")

    travel_to Time.zone.local(2026, 8, 29, 12, 34) do
      get new_chat_url

      assert_response :success
      assert_select "turbo-frame#title_chat h3", text: "Neuer Chat 2026-08-29 12:34"
    end
  end

  test "gets new chat with the existing English default title" do
    @user.update!(locale: "en")

    travel_to Time.zone.local(2026, 8, 29, 12, 34) do
      get new_chat_url

      assert_response :success
      assert_select "turbo-frame#title_chat h3", text: "New chat 2026-08-29 12:34"
    end
  end

  test "creates chat" do
    assert_difference("Chat.count") do
      post chats_url, params: { chat: { content: "Hello", ai_model: "gpt-4.1" } }
    end

    chat = Chat.order(created_at: :desc).first

    assert_redirected_to chat_path(chat, thinking: true)
    assert_equal "Hello", chat.title
    assert_equal "Hello", chat.messages.find_by!(type: "UserMessage").content
  end

  test "creates chat with attached context" do
    account = accounts(:depository)

    assert_difference("Chat.count") do
      post chats_url, params: {
        chat: {
          content: "Tell me about this",
          ai_model: "gpt-4.1",
          composer_context: [ { type: "account", id: account.id } ].to_json
        }
      }
    end

    chat = Chat.order(created_at: :desc).first
    message = chat.messages.find_by!(type: "UserMessage")
    assert_includes message.content, account.name
    assert_includes message.content, "Tell me about this"
  end

  test "shows chat" do
    chat = chats(:one)
    @user.update!(last_viewed_chat: nil)

    get chat_url(chat)

    assert_response :success
    assert_equal chat, @user.reload.last_viewed_chat
    assert_select "[data-testid=chat-add-context]"
    assert_select "[data-testid=chat-commands]"
    assert_select "[data-testid=chat-mention]"
    assert_select "[data-testid=chat-page-context]"
    assert_no_match(/Coming soon/i, response.body)
  end

  test "slash commands include categorize and recurring" do
    get new_chat_url

    assert_response :success
    assert_match "/categorize", response.body
    assert_match "/recurring", response.body
    assert_match "/rule", response.body
    assert_match "/split", response.body
    assert_match "/report", response.body
    assert_match "/debt", response.body
  end

  test "destroys chat" do
    assert_difference("Chat.count", -1) do
      delete chat_url(chats(:one))
    end

    assert_redirected_to chats_url
  end

  test "should not allow access to other user's chats" do
    other_user = users(:family_member)
    other_chat = Chat.create!(user: other_user, title: "Other User's Chat")

    get chat_url(other_chat)
    assert_response :not_found

    delete chat_url(other_chat)
    assert_response :not_found
  end
end
